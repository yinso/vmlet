#loglet = require '#loglet'
errorlet = require 'errorlet'
AST = require './ast'
baseEnv = require './baseenv'
Environment = require './environment'
ParamList = require './parameter'
LexicalEnvironment = require './lexical'
tr = require './trace'

_transTypes = {}

register = (ast, transformer) ->
  if _transTypes.hasOwnProperty(ast.type)
    throw errorlet.create {error: 'anf_duplicate_ast_type', type: ast.type}
  else
    _transTypes[ast.type] = transformer
  
get = (ast) ->
  if _transTypes.hasOwnProperty(ast.constructor.type)
    _transTypes[ast.constructor.type]
  else
    throw errorlet.create {error: 'anf_unsupported_ast_type', type: ast.constructor.type}

override = (ast, transformer) ->
  _transTypes[ast.type] = transformer

assign = (ast, env, block, sym = LexicalEnvironment.defaultPrefix) ->
  ref = env.defineTemp ast
  block.push ref.local()
  ref
  #varName = env.assign ast, sym
  #block.push AST.tempvar(varName, ast)
  #AST.symbol varName

normalize = (ast) ->
  switch ast.type()
    when 'block'
      normalizeBlock ast
    else
      ast 

normalizeBlock = (ast) ->
  items = []
  for item, i in ast.items 
    if i < ast.items.length - 1 
      switch item.type()
        when 'local', 'define'
          items.push item
    else
      items.push switch item.type()
        when 'local'
          item.normalized()
        when 'define'
          item.value
        else
          item
  if items.length == 1 
    items[0]
  else
    AST.block items

# this version doesn't use ANF the type... it just uses BLOCK instead.
transform = (ast, env = new LexicalEnvironment(baseEnv), block = AST.block([])) ->
  _transform ast, env, block
  normalize block

_transformInner = (ast, env, block = AST.block()) ->
  _transform ast, env, block 
  block

_transform = (ast, env, block = AST.block()) ->
  transformer = get ast 
  transformer ast, env, block

transformScalar = (ast, env, block) ->
  block.push ast

register AST.get('number'), transformScalar
register AST.get('bool'), transformScalar
register AST.get('null'), transformScalar
register AST.get('string'), transformScalar
register AST.get('ref'), transformScalar

transformProc = (ast, env, block) ->
  assign ast, env, block
register AST.get('procedure'), transformProc
register AST.get('task'), transformProc

transformBinary = (ast, env, block) ->
  ##loglet.log '--anf.binary', ast
  lhs = _transform ast.lhs, env, block
  rhs = _transform ast.rhs, env, block
  assign AST.binary(ast.op, lhs, rhs), env, block
  
register AST.get('binary'), transformBinary

transformIf = (ast, env, block) ->
  cond = _transform ast.cond, env, block
  thenAST = _transformInner ast.then, env
  elseAST = _transformInner ast.else, env
  ##loglet.log '--anf.cond', ast, cond, thenAST, elseAST
  assign AST.if(cond, thenAST, elseAST), env, block

register AST.get('if'), transformIf

transformBlock = (ast, env, block) ->
  newEnv = new LexicalEnvironment env
  for i in [0...ast.items.length - 1]
    _transform ast.items[i], newEnv, block
  res = _transform ast.items[ast.items.length - 1], newEnv, block
  res

register AST.get('block'), transformBlock

transformDefine = (ast, env, block) ->
  ##loglet.log '--anf.define', ast
  res = transform ast.value, env
  env.define ast.name, res
  block.push AST.define(ast.name, res)
  res

register AST.get('define'), transformDefine

transformLocal = tr.trace 'anf.local', (ast, env, block) ->
  res = transform ast.normalized(), env
  cloned = ast.clone res
  block.push cloned
  cloned

register AST.get('local'), transformLocal

transformIdentifier = (ast, env, block) ->
  ast
  
register AST.get('symbol'), transformIdentifier

transformObject = (ast, env, block) ->
  keyVals = 
    for [key, val] in ast.value
      v = _transform val, env, block
      [key, v]
  assign AST.object(keyVals), env, block

register AST.get('object'), transformObject

transformArray = (ast, env, block) ->
  items = 
    for v in ast.value
      _transform v, env, block
  assign AST.array(items), env, block

register AST.get('array'), transformArray

transformMember = (ast, env, block) ->
  head = _transform ast.head, env, block
  assign AST.member(head, ast.key), env, block

register AST.get('member'), transformMember

transformFuncall = (ast, env, block) ->
  #loglet.log '--anf.transformFuncall', ast, block
  args = 
    for arg in ast.args
      _transform arg, env, block
  funcall = _transform ast.funcall, env, block
  ast = AST.funcall funcall, args
  assign ast, env, block

register AST.get('funcall'), transformFuncall

transformTaskcall = (ast, env, block) ->
  #loglet.log '--anf.transformTaskcall', ast, block
  args = 
    for arg in ast.args
      _transform arg, env, block
  funcall = _transform ast.funcall, env, block
  assign AST.taskcall(funcall, args), env, block

register AST.get('taskcall'), transformTaskcall

transformParam = (ast, env, block) ->
  ast
  
register AST.get('param'), transformParam

makeProc = (type) ->
  (ast, env, block) ->
    #Transformer.transform ast # this will cause recursion overflow... how do I overcome this issue? 
    
    newEnv = new LexicalEnvironment env
    #name = 
    #  if ast.name
    #    newEnv.defineRef ast.name
    #  else
    #    undefined
    #params = 
    #  for param in ast.params
    #    newEnv.mapParam param
    #body = Transformer.transform ast.body, newEnv
    body = _transformInner ast.body, newEnv
    #console.log '--anf.makeProc', ast.body, body
    ast = AST.make type, ast.name or undefined, ast.params, body
    assign ast, env, block

#register AST.get('procedure'), makeProc('procedure')
#register AST.get('task'), makeProc('task')
#register AST.get('procedure'), Transformer.transform
#register AST.get('task'), Transformer.transform

transformThrow = (ast, env, block) ->
  exp = _transform ast.value, env, block
  block.push AST.throw exp
  
register AST.get('throw'), transformThrow

transformCatch = (ast, env, block) ->
  #loglet.log '--anf.transformCatch', ast
  newEnv = new LexicalEnvironment env
  ref = newEnv.defineParam ast.param
  body = transform ast.body, newEnv
  AST.catch ast.param, body

transformFinally = (ast, env, block) ->
  #loglet.log '--anf.transformFinally', ast
  newEnv = new LexicalEnvironment env
  body = _transform ast.body, newEnv
  AST.finally body

transformTry = (ast, env, block) ->
  #loglet.log '--anf.transformTry', ast
  newEnv = new LexicalEnvironment env
  body = transform ast.body, newEnv
  catches = 
    for c in ast.catches
      transformCatch c, env, block
  fin = 
    if ast.finally instanceof AST
      transformFinally ast.finally, env, block
    else
      null
  #loglet.log '--anf.transformTry', body, catches, fin
  block.push AST.try(body, catches, fin)

register AST.get('try'), transformTry

module.exports = 
  register: register
  get: get
  override: override
  transform: transform

