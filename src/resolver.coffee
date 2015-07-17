# resolver is to resolve the dangling symbols/identifiers to make sure that they are properly assigned.
# this would look very similar to ANF transformation in many ways...
loglet = require 'loglet'
errorlet = require 'errorlet'
AST = require './ast'
SymbolTable = require './symboltable'
tr = require './trace'
T = require './transformer'
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

transform = (ast, env) ->
  switch ast.type()
    when 'toplevel', 'module'
      resolved = _transform ast.body, env
      anf = ANF.transform resolved, env
      T.transform ast.clone(AST.return(anf))
    else
      resolved = _transform ast, env
      anf = ANF.transform resolved, env
      T.transform AST.return(anf)

_transform = (ast, env) ->
  resolver = get(ast)
  resolver ast, env

transformScalar = (ast, env) ->
  ast

register AST.get('number'), transformScalar
register AST.get('bool'), transformScalar
register AST.get('null'), transformScalar
register AST.get('string'), transformScalar
register AST.get('ref'), transformScalar
register AST.get('unit'), transformScalar

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
  # block doesn't introduce new scoping... 
  # maybe that's better... hmm...
  # function and let introduce new scoping.
  #newEnv = new SymbolTable env
  items = 
    for i in [0...ast.items.length]
      _transform ast.items[i], env
  AST.block items

register AST.get('block'), transformBlock

transformTopLevel = (ast, env) ->
  AST.toplevel _transform(ast.body, env)

register AST.get('toplevel'), transformTopLevel

transformDefine = (ast, env) ->
  if env.has ast.name 
    throw new Error("duplicate_define: #{ast.name}")
  ref = env.define ast.name 
  res = _transform ast.value, env
  ref.value = res # update the value.
  #console.log '-- resolver.define', ref, env.level(), env
  if env.level() <= 1 # this is arbitrary decided for now... base + toplevel block ?
    ref.isDefine = true
  ref.define()

register AST.get('define'), transformDefine

transformIdentifier = (ast, env) ->
  #console.log 'RESOLVER.identifier', ast, env
  if env.has ast
    env.get ast
  else
    throw errorlet.create {error: 'RESOLVER.transform:unknown_identifier', id: ast}  
  
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
    newEnv = new SymbolTable env
    params = 
      for param in ast.params
        newEnv.defineParam param
    decl = AST.make type, ast.name, params, null 
    if ast.name 
      if env.has(ast.name) and env.get(ast.name).isPlaceholder()
        env.get(ast.name).value = decl
      else # it's not defined at a higher level, we need to create our own definition.
        newEnv.define ast.name , decl 
    body = _transform ast.body, newEnv
    decl.body = body
    T.transform decl

register AST.get('procedure'), makeProc('procedure')
register AST.get('task'), makeProc('task')

transformThrow = (ast, env) ->
  exp = _transform ast.value, env
  AST.make 'throw', exp

register AST.get('throw'), transformThrow

transformCatch = (ast, env) ->
  newEnv = new SymbolTable env
  ref = newEnv.defineParam ast.param
  body = _transform ast.body, newEnv
  AST.make 'catch', ast.param, body

transformFinally = (ast, env) ->
  newEnv = new SymbolTable env
  body = _transform ast.body, newEnv
  AST.make 'finally', body

transformTry = (ast, env) ->
  newEnv = new SymbolTable env
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

transformImport = (ast, env) ->
  # when we are transforming import, we are introducing bindings.
  if ast.bindings.length > 0
    for binding in ast.bindings 
      env.define binding.name, binding
  ast

register AST.get('import'), transformImport 

module.exports =
  transform: transform
  register: register
  get: get

