AST = require './ast'
escodegen = require 'escodegen'
#Environment = require './symboltable'

class Environment 
  constructor: (@prev = null) ->
    @inner = {}
    @symMap = 
      if @prev 
        @prev.symMap 
      else
        {}
  _has: (sym) ->
    @inner.hasOwnProperty sym.value 
  has: (sym) ->
    if @_has(sym)
      true
    else if @prev
      @prev.has sym
    else
      false
  get: (sym) ->
    if @_has sym
      @inner[sym.value]
    else if @prev 
      @prev.get sym 
    else
      throw new Error("unknown_identifier: #{sym}")
  gensym: (sym) ->
    @symMap[sym.value] = 
      if @symMap.hasOwnProperty(sym.value)
        @symMap[sym.value] + 1
      else
        1
    AST.symbol("#{sym.value}$#{@symMap[sym.value]}")
  alias: (sym) ->
    newSym = 
      if @prev?.has(sym)
        @gensym sym 
      else
        sym 
    @inner[sym.value] = newSym
    newSym
  defineParam: (param) ->
    alias = @alias param.name 
    AST.param alias, param.paramType, param.default 
  define: (sym, val) ->
    alias = @alias sym 
    AST.define alias, val 
  local: (sym, val) ->
    alias = @alias sym 
    AST.local alias, val 

_types = {}

register = (type, trans) ->
  if _types.hasOwnProperty(type.type)
    throw new Error("UNIQUE.register:type_exists: #{type.type}")
  _types[type.type] = trans

get = (ast) ->
  if not _types.hasOwnProperty(ast.type())
    throw new Error("UNIQUE.register:unknown_type: #{ast.type()}: #{ast}")
  _types[ast.type()]

transform = (ast, env = new Environment()) ->
  trans = get ast
  res = trans ast, env 
  res
transScalar = (ast, env) ->
  ast

register AST.get('number'), transScalar
register AST.get('string'), transScalar
register AST.get('bool'), transScalar
register AST.get('null'), transScalar
register AST.get('unit'), transScalar

transDefine = (ast, env) ->
  name = transform ast.name 
  AST.define name, transform(ast.value)

register AST.get('define'), transDefine

transLocal = (ast, env) ->
  name = transform ast.name 
  AST.local name , if ast.value then transform(ast.value) else ast.value 

register AST.get('local'), transLocal 

transAssign = (ast, env) ->
  name = transform ast.name 
  AST.assign name , if ast.value then transform(ast.value) else ast.value 

register AST.get('assign'), transAssign

transSymbol = (ast, env) ->
  if not env.has(ast)
    env.alias ast 
  else
    env.get ast

register AST.get('symbol'), transSymbol

transRef = (ast, env) ->
  transSymbol ast.name, env

register AST.get('ref'), transRef

transBlock = (ast, env) ->
  newEnv = new Environment env 
  items = 
    for item in ast.items 
      transform item, newEnv 
  AST.block items 

register AST.get('block'), transBlock

transArray = (ast, env) ->
  items = 
    for item in ast.value
      transform item, env 
  AST.array items

register AST.get('array'), transArray 

transObject = (ast, env) ->
  keyvals = 
    for [ key , val ] in ast.value 
      [ key , transform(val, env) ]
  AST.object keyvals

register AST.get('object'), transObject

transBinary = (ast, env) ->
  AST.binary ast.op, transform(ast.lhs, env), transform(ast.rhs, env)

register AST.get('binary'), transBinary 

transIf = (ast, env) ->
  AST.if transform(ast.cond, env), transform(ast.then, env), transform(ast.else, env)

register AST.get('if'), transIf

transTry = (ast, env) ->
  catches = 
    for c in ast.catches 
      transCatch c, env
  finalAST =
    if ast.finally 
      transFinally ast.finally, env
    else
      ast.finally
  AST.try transform(ast.body), catches, finalAST

register AST.get('try'), transTry

transCatch = (ast, env) ->
  newEnv = new Environment(env)
  param = newEnv.defineParam ast.param 
  body = transform ast.body, newEnv
  AST.catch param, body

transFinally = (ast, env) ->
  if ast
    transform ast.body, env
  else
    ast

transFuncall = (ast, env) ->
  funcall = transform ast.funcall, env
  args = 
    for arg in ast.args 
      transform arg, env
  AST.funcall funcall, args

register AST.get('funcall'), transFuncall
register AST.get('taskcall'), transFuncall

transReturn = (ast, env) ->
  AST.return transform(ast.value, env)

register AST.get('return'), transReturn

transProcedure = (ast, env) ->
  newEnv = new Environment env 
  params = 
    for param in ast.params 
      newEnv.defineParam param 
  name = 
    if ast.name 
      if env.has ast.name 
        env.get ast.name 
      else
        newEnv.alias ast.name 
    else
      ast.name 
  body = transform ast.body, newEnv
  AST.procedure ast.name, params, body 

register AST.get('procedure'), transProcedure

transTask = (ast, env) ->
  newEnv = new Environment env 
  params = 
    for param in ast.params 
      newEnv.defineParam param 
  name = 
    if ast.name 
      if env.has ast.name 
        env.get ast.name 
      else
        newEnv.alias ast.name 
    else
      ast.name 
  body = transform ast.body, newEnv
  AST.task ast.name, params, body 

register AST.get('task'), transTask

module.exports = 
  register: register
  transform: transform
