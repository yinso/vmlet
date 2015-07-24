# resolver is to resolve the dangling symbols/identifiers to make sure that they are properly assigned.
# this would look very similar to ANF transformation in many ways...
loglet = require 'loglet'
errorlet = require 'errorlet'
AST = require './ast'
SymbolTable = require './symboltable'
tr = require './trace'
util = require './util'

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
      ast.clone resolved
    else
      _transform ast, env

_transform = (ast, env) ->
  resolver = get(ast)
  resolver ast, env

_scalar = (ast, env) ->
  ast

register AST.get('number'), _scalar
register AST.get('bool'), _scalar
register AST.get('null'), _scalar
register AST.get('string'), _scalar
register AST.get('ref'), _scalar
register AST.get('unit'), _scalar

_binary = (ast, env) ->
  lhs = _transform ast.lhs, env
  rhs = _transform ast.rhs, env
  AST.binary ast.op, lhs, rhs
  
register AST.get('binary'), _binary

_if = (ast, env) ->
  cond = _transform ast.cond, env
  thenAST = _transform ast.then, env
  elseAST = _transform ast.else, env
  AST.if cond, thenAST, elseAST

register AST.get('if'), _if

_block = (ast, env) ->
  # block doesn't introduce new scoping... 
  # maybe that's better... hmm...
  # function and let introduce new scoping.
  #newEnv = new SymbolTable env
  # first pull out all of the defines. 
  for item, i in ast.items 
    if item.type() == 'define'
      _defineName item, env
  items = 
    for item, i in ast.items
      if item.type() == 'define'
        _defineVal item, env
      else
        _transform item, env
  AST.block items

register AST.get('block'), _block

_toplevel = (ast, env) ->
  AST.toplevel _transform(ast.body, env)

register AST.get('toplevel'), _toplevel

_defineName = (ast, env) ->
  if env.hasCurrent ast.name 
    throw new Error("duplicate_define: #{ast.name}")
  ref = env.define ast.name 
  if env.level() <= 1 
    ref.isDefine = true 

_defineVal = (ast, env) ->
  # at this time we assume define exists... 
  ref = env.get ast.name 
  res = _transform  ast.value, env 
  ref.value = res 
  ref.define()

_define = tr.trace 'resolver.define', (ast, env) ->
  _defineName ast, env
  _defineVal ast, env

register AST.get('define'), _define

_identifier = (ast, env) ->
  #console.log 'RESOLVER.identifier', ast, env
  if env.has ast
    env.get ast
  else
    throw errorlet.create {error: 'RESOLVER.transform:unknown_identifier', id: ast}  
  
register AST.get('symbol'), _identifier

_object = (ast, env) ->
  keyVals = 
    for [key, val] in ast.value
      v = _transform val, env
      [key, v]
  AST.object keyVals

register AST.get('object'), _object

_array = (ast, env) ->
  items = 
    for v in ast.value
      _transform v, env
  AST.array items

register AST.get('array'), _array

_member = (ast, env) ->
  head = _transform ast.head, env
  AST.member head, ast.key

register AST.get('member'), _member

_funcall = (ast, env) ->
  args = 
    for arg in ast.args
      _transform arg, env
  # console.log '-- transform.funcall', ast.funcall, env
  funcall = _transform ast.funcall, env
  AST.make 'funcall', funcall, args

register AST.get('funcall'), _funcall

_taskcall = (ast, env) ->
  args = 
    for arg in ast.args
      _transform arg, env
  funcall = _transform ast.funcall, env
  AST.make('taskcall', funcall, args)

register AST.get('taskcall'), _taskcall

_param = (ast, env) ->
  ast
  
register AST.get('param'), _param

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
    decl.body = _transform ast.body, newEnv
    decl

register AST.get('procedure'), makeProc('procedure')
register AST.get('task'), makeProc('task')

_throw = (ast, env) ->
  exp = _transform ast.value, env
  AST.make 'throw', exp

register AST.get('throw'), _throw

_catch = (ast, env) ->
  newEnv = new SymbolTable env
  ref = newEnv.defineParam ast.param
  body = _transform ast.body, newEnv
  AST.make 'catch', ast.param, body

_finally = (ast, env) ->
  newEnv = new SymbolTable env
  body = _transform ast.body, newEnv
  AST.make 'finally', body

_try = (ast, env) ->
  newEnv = new SymbolTable env
  body = _transform ast.body, newEnv
  catches = 
    for c in ast.catches
      _catch c, env
  fin = 
    if ast.finally instanceof AST
      _finally ast.finally, env
    else
      null
  AST.make('try', body, catches, fin)

register AST.get('try'), _try

_import = (ast, env) ->
  # when we are transforming import, we are introducing bindings.
  for binding in ast.bindings 
    env.define binding.as, ast.proxy(binding)
  ast

register AST.get('import'), _import 

_export = (ast, env) ->
  bindings = 
    for binding in ast.bindings 
      if not env.has binding.spec 
        throw new Error("export:unknown_identifier: #{binding.binding}")
      else
        AST.binding(env.get(binding.spec), binding.as)
  AST.export(bindings)

register AST.get('export'), _export

_let = (ast, env) ->
  newEnv = new SymbolTable env
  defines = 
    for define in ast.defines 
      _transform define , newEnv
  body = _transform ast.body , newEnv 
  AST.let defines, body

register AST.get('let'), _let

module.exports =
  transform: transform
  register: register
  get: get

