escodegen = require 'escodegen'
esnode = require './esnode'
AST = require './ast'
util = require './util'
TR = require './trace'
Hashmap = require './hashmap'

types = {}
register = (ast, compiler) ->
  if types.hasOwnProperty(ast.type)
    throw new Error("compiler:duplicate_type: #{ast.type}")
  types[ast.type] = compiler

get = (ast) ->
  if types.hasOwnProperty(ast.type())
    types[ast.type()]
  else
    throw new Error("compiler:unknown_type: #{ast.type()}")

hashCode = (str) ->
  hash = 0
  if str.length == 0
    return hash
  for i in [0...str.length]
    char = str.charCodeAt i 
    hash = ((hash<<5) - hash) + char
    hash = hash & hash 
  return hash

class Environment 
  # strictly speaking we don't need prev? but it's still nice to have it I think.
  constructor: (@prev = null) ->
    @dupes = {}
    @inner = new Hashmap
      hashCode: hashCode
  has: (key) ->
    @inner.has key
  get: (key) ->
    if not @has key
      throw new Error("escompile:unknown_identifier: #{key}")
    else
      @inner.get key
  alias: (key) -> 
    if @has key 
      @get key
    else 
      newKey = @newKey key 
      @inner.set key, newKey
      newKey
  newKey: (key) -> 
    name = key.value
    if not @dupes.hasOwnProperty(name)
      @dupes[name] = 0
    else
      @dupes[name]++ 
    if @dupes[name] == 0
      esnode.identifier(name)
    else
      esnode.identifier(name + "$" + @dupes[name])
  
compile = (ast) ->
  node = _compile ast, new Environment()
  '(' + escodegen.generate(node)  + ')'

_compile = (ast, env, res) ->
  compiler = get ast
  compiler ast, env

_literal = (ast, env) ->
  esnode.literal ast.value 

register AST.get('string'), _literal
register AST.get('bool'), _literal

_number = (ast, env) ->
  if ast.value < 0 
    esnode.unary '-', esnode.literal -ast.value
  else
    esnode.literal ast.value

register AST.get('number'), _number

_null = (ast, env) ->
  esnode.null_()

register AST.get('null'), _null

_undefined = (ast, env) ->
  esnode.undefined_()

register AST.get('unit'), _undefined

_member = (ast, env) ->
  head = _compile ast.head, env
  key = 
    if ast.key.type() == 'symbol'
      esnode.literal(ast.key.value)
    else
      _compile ast.key, env
  esnode.funcall esnode.member(_compile(AST.runtimeID, env), esnode.identifier('member')), [ head , key ]

register AST.get('member'), _member

_symbol = (ast, env) ->
  env.alias ast
  #esnode.identifier(ast.value)

register AST.get('symbol'), _symbol

_object = (ast, env) ->
  esnode.object ([key, _compile(val, env)] for [key, val] in ast.value)

register AST.get('object'), _object

_array = (ast, env) ->
  esnode.array (_compile(item, env) for item in ast.value)

register AST.get('array'), _array

_block = (ast, env) ->
  esnode.block (_compile(item, env) for item in ast.items)

register AST.get('block'), _block

_assign = (ast, env) ->
  esnode.assign _compile(ast.name, env), _compile(ast.value, env)

register AST.get('assign'), _assign  

_define = (ast, env) ->
  name = 
    switch ast.name.type()
      when 'ref'
        esnode.literal ast.name.name.value
      when 'symbol'
        esnode.literal ast.name.value
      else
        throw new Error("escompile.define:unknown_name_type: #{ast.name}")
  value = 
    esnode.funcall esnode.member(_compile(AST.moduleID, env), esnode.identifier('define')),
      [ name , _compile(ast.value, env) ]
  id = 
    switch ast.name.type()
      when 'ref'
        _compile(ast.name.normalName(), env)
      when 'symbol'
        _compile(ast.name, env)
      else
        throw new Error("escompile.define:unknown_name_type: #{ast.name}")
  esnode.declare 'var', [ id, value ]
  
register AST.get('define'), _define

_local = (ast, env) ->
  if not ast.value
    esnode.declare 'var', [ _compile(ast.name, env) ]
  else
    esnode.declare 'var', [ _compile(ast.name, env) , _compile(ast.value, env) ]

register AST.get('local'), _local

_ref = (ast, env) ->
  if ast.value.type() == 'proxyval'
    _compile ast.value, env
  else if ast.isDefine
    esnode.funcall esnode.member(_compile(AST.moduleID, env), esnode.identifier('get')), 
      [ esnode.literal(ast.name.value) ]
  else
    _compile ast.name, env
  
register AST.get('ref'), _ref

_proxyval = (ast, env) ->
  res = 
    if typeof(ast.compiler) == 'function' or ast.compiler instanceof Function 
      ast.compiler(env)
    else if ast.compiler instanceof AST
      _compile ast.compiler, env
    else
      _compile ast.name, env
  res

register AST.get('proxyval'), _proxyval

_param = (ast, env) ->
  _compile ast.name, env

register AST.get('param'), _param 

_procedure = (ast, env) ->
  name = if ast.name then _compile(ast.name, env) else null
  func = esnode.function name, (_compile(param, env) for param in ast.params), _compile(ast.body, env)
  maker = esnode.member(_compile(AST.runtimeID, env), esnode.identifier('proc'))
  esnode.funcall maker, [ func ]

register AST.get('procedure'), _procedure

_task = (ast, env) ->
  name = if ast.name then _compile(ast.name, env) else null
  esnode.function name, (_compile(param, env) for param in ast.params), _compile(ast.body, env)

register AST.get('task'), _task

_if = (ast, env) ->
  esnode.if _compile(ast.cond, env), _compile(ast.then, env), _compile(ast.else, env)

register AST.get('if'), _if

_funcall = (ast, env) ->
  esnode.funcall _compile(ast.funcall, env), (_compile(arg, env) for arg in ast.args)

register AST.get('funcall'), _funcall
register AST.get('taskcall'), _funcall

_return = (ast, env) ->
  esnode.return _compile(ast.value, env) 

register AST.get('return'), _return 

_binary = (ast, env) ->
  esnode.binary ast.op, _compile(ast.lhs, env), _compile(ast.rhs, env)
  
register AST.get('binary'), _binary

_throw = (ast, env) ->
  esnode.throw _compile(ast.value, env)

register AST.get('throw'), _throw 

_catch = (ast, env) ->
  esnode.catch _compile(ast.param, env), _compile(ast.body, env)
  
_finally = (ast, env) ->
  _compile ast, env

_try = (ast, env) ->
  esnode.try _compile(ast.body, env), (_catch(exp, env) for exp in ast.catches), if ast.finally then _finally(ast.finally, env) else null

register AST.get('try'), _try

_toplevel = (ast, env) ->
  _rt = _compile(AST.runtimeID, env)
  imports = esnode.array(_importSpec(imp, env) for imp in ast.imports)
  params = 
    [ _compile(ast.moduleParam, env) ].concat(_importID(imp, env) for imp in ast.imports).concat([ _compile(ast.callbackParam, env) ])
  proc = esnode.function null, params, _compile(ast.body, env)
  esnode.funcall esnode.member(_rt, esnode.identifier('toplevel')),
    [ 
      imports 
      proc 
    ]

register AST.get('toplevel'), _toplevel

_module = (ast, env) ->
  _rt = _compile(AST.runtimeID, env)
  imports = esnode.array(_importSpec(imp, env) for imp in ast.imports)
  params = 
    [ _compile(ast.moduleParam, env) ].concat(_importID(imp, env) for imp in ast.imports).concat([ _compile(ast.callbackParam, env) ])
  proc = esnode.function null, params, _compile(ast.body, env)
  esnode.funcall esnode.member(_rt, esnode.identifier('module')),
    [
      _compile(ast.spec, env)
      imports
      proc
    ]

register AST.get('module'), _module

_importSpec = (ast, env) ->
  _compile ast.spec, env

_importID = (ast, env) ->
  _compile ast.idParam, env

_importBinding = (ast, binding, env) ->
  [ _compile(binding.as, env) , esnode.member(_importID(ast, env), _compile(binding.spec, env)) ]
  
_import = (ast, env) ->
  esnode.declare 'var', (_importBidning(ast, binding, env) for binding in ast.bindings)...

register AST.get('import'), _import  

_export = (ast, env) ->
  esnode.funcall esnode.member(_compile(AST.moduleID, env), esnode.identifier('export')), 
    [ 
      esnode.object ([binding.as.value, _compile(binding.spec, env)] for binding in ast.bindings)
    ]

register AST.get('export'), _export

module.exports = 
  compile: compile
  register: register
  get: get
