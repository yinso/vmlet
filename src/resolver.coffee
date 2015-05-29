# resolver is to resolve the dangling symbols/identifiers to make sure that they are properly assigned.
# this would look very similar to ANF transformation in many ways...
loglet = require 'loglet'
errorlet = require 'errorlet'
AST = require './ast'
baseEnv = require './baseenv'
Environment = require './environment'
ParamList = require './parameter'
LexicalEnvironment = require './lexical'
tr = require './trace'
Transformer = require './transformer'
require './ret'
ANF = require './anf'

_transTypes = {}

register = (ast, transformer) ->
  if _transTypes.hasOwnProperty(ast.type)
    throw errorlet.create {error: 'resolver_duplicate_ast_type', type: ast.type}
  else
    _transTypes[ast.type] = transformer
  
get = (ast) ->
  if _transTypes.hasOwnProperty(ast.constructor.type)
    _transTypes[ast.constructor.type]
  else
    throw errorlet.create {error: 'resolver_unsupported_ast_type', type: ast.constructor.type}

transform = tr.trace 'resolver.transform', (ast, env) ->
  resolved = _transform ast, env
  anf = ANF.transform resolved
  Transformer.transform AST.return(anf)



_transform = (ast, env) ->
  resolver = get(ast)
  resolver ast, env

transformScalar = (ast, env) ->
  ast

register AST.get('number'), transformScalar
register AST.get('bool'), transformScalar
register AST.get('null'), transformScalar
register AST.get('string'), transformScalar

transformBinary = (ast, env) ->
  lhs = _transform ast.lhs, env
  rhs = _transform ast.rhs, env
  AST.binary ast.op, lhs, rhs
  
register AST.get('binary'), transformBinary

transformIf = (ast, env) ->
  cond = _transform ast.cond, env
  thenAST = _transform ast.then, env
  elseAST = _transform ast.else, env
  AST.if cond, thenAST, elseAST

register AST.get('if'), transformIf

transformBlock = (ast, env) ->
  newEnv = new LexicalEnvironment env
  items = 
    for i in [0...ast.items.length]
      _transform ast.items[i], newEnv
  AST.block items

register AST.get('block'), transformBlock

transformDefine = (ast, env) ->
  if env.has ast.name 
    throw new Error("duplicate_define: #{ast.name}")
  res = _transform ast.value, env
  if env.level() == 0
    env.define ast.name, res
    AST.define ast.name, res
  else
    ref = env.defineLocal ast.name, res
    local = ref.local()
    tr.log '--transform.define.local', ast.name, res, ref, local
    local

register AST.get('define'), tr.trace 'resolve.define', transformDefine

transformIdentifier = (ast, env) ->
  #console.log '--transform.identifier', ast.value, env, env.has(ast.value)
  if env.has ast.value
    env.get ast.value
  else
    throw errorlet.create {error: 'ANF.transform:unknown_identifier', id: ast.value}  
  
register AST.get('symbol'), transformIdentifier

transformObject = (ast, env) ->
  keyVals = 
    for [key, val] in ast.value
      v = _transform val, env
      [key, v]
  AST.object keyVals

register AST.get('object'), transformObject

transformArray = (ast, env) ->
  items = 
    for v in ast.value
      _transform v, env
  AST.array items

register AST.get('array'), transformArray

transformMember = (ast, env) ->
  head = _transform ast.head, env
  AST.member head, ast.key

register AST.get('member'), transformMember

transformFuncall = (ast, env) ->
  args = 
    for arg in ast.args
      _transform arg, env
  # console.log '-- transform.funcall', ast.funcall, env
  funcall = _transform ast.funcall, env
  AST.make 'funcall', funcall, args

register AST.get('funcall'), transformFuncall

transformTaskcall = (ast, env) ->
  args = 
    for arg in ast.args
      _transform arg, env
  funcall = _transform ast.funcall, env
  AST.make('taskcall', funcall, args)

register AST.get('taskcall'), transformTaskcall

transformParam = (ast, env) ->
  ast
  
register AST.get('param'), transformParam

makeProc = (type) ->
  (ast, env) ->
    newEnv = new LexicalEnvironment env
    name = 
      if ast.name
        newEnv.defineRef ast.name
      else
        undefined
    params = 
      for param in ast.params
        newEnv.defineParam param
    #console.log '-- make.proc', type, newEnv
    body = _transform ast.body, newEnv
    res = AST.make type, name?.name, params, ANF.transform(body)
    Transformer.transform res

register AST.get('procedure'), makeProc('procedure')
register AST.get('task'), makeProc('task')

transformThrow = (ast, env) ->
  exp = _transform ast.value, env
  AST.make 'throw', exp

register AST.get('throw'), transformThrow

transformCatch = (ast, env) ->
  newEnv = new LexicalEnvironment env
  ref = newEnv.defineParam ast.param
  body = _transform ast.body, newEnv
  AST.make 'catch', ast.param, body

transformFinally = (ast, env) ->
  newEnv = new LexicalEnvironment env
  body = _transform ast.body, newEnv
  AST.make 'finally', body

transformTry = (ast, env) ->
  newEnv = new LexicalEnvironment env
  body = _transform ast.body, newEnv
  catches = 
    for c in ast.catches
      transformCatch c, env
  fin = 
    if ast.finally instanceof AST
      transformFinally ast.finally, env
    else
      null
  AST.make('try', body, catches, fin)

register AST.get('try'), transformTry

module.exports =
  transform: transform
  register: register
  get: get

