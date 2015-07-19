escodegen = require 'escodegen'
esnode = require './esnode'
AST = require './ast'
util = require './util'
TR = require './trace'

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

class Environment 
  # strictly speaking we don't need prev? but it's still nice to have it I think.
  constructor: (@prev = null) ->
    @inner = {}
  _has: (key) ->
    
compile = (ast) ->
  node = _compile ast
  '(' + escodegen.generate(node)  + ')'

_compile = (ast, env, res) ->
  compiler = get ast
  compiler ast

_literal = (ast) ->
  esnode.literal ast.value 

register AST.get('string'), _literal
register AST.get('bool'), _literal

_number = (ast) ->
  if ast.value < 0 
    esnode.unary '-', esnode.literal -ast.value
  else
    esnode.literal ast.value

register AST.get('number'), _number

_null = (ast) ->
  esnode.null_()

register AST.get('null'), _null

_undefined = (ast) ->
  esnode.undefined_()

register AST.get('unit'), _undefined

_member = (ast) ->
  head = _compile ast.head
  key = 
    if ast.key.type() == 'symbol'
      esnode.literal(ast.key.value)
    else
      _compile ast.key
  esnode.funcall esnode.member(esnode.identifier('_rt'), esnode.identifier('member')), [ head , key ]
register AST.get('member'), _member

_symbol = (ast) ->
  esnode.identifier(ast.value)

register AST.get('symbol'), _symbol

_object = (ast) ->
  esnode.object ([key, _compile(val)] for [key, val] in ast.value)

register AST.get('object'), _object

_array = (ast) ->
  esnode.array (_compile(item) for item in ast.value)

register AST.get('array'), _array

_block = (ast) ->
  esnode.block (_compile(item) for item in ast.items)

register AST.get('block'), _block

_assign = (ast) ->
  esnode.assign _compile(ast.name), _compile(ast.value)

register AST.get('assign'), _assign  

_define = (ast) ->
  name = 
    switch ast.name.type()
      when 'ref'
        esnode.literal ast.name.name.value
      when 'symbol'
        esnode.literal ast.name.value
      else
        throw new Error("AST.define.toESNode:unknown_name_type: #{ast.name}")
  value = 
    esnode.funcall esnode.member(esnode.identifier('_module'), esnode.identifier('define')),
      [ name , _compile(ast.value) ]
  id = 
    switch ast.name.type()
      when 'ref'
        _compile(ast.name.normalName())
      when 'symbol'
        _compile(ast.name)
      else
        throw new Error("AST.define.toESNode:unknown_name_type: #{ast.name}")
  esnode.declare 'var', [ id, value ]
  
register AST.get('define'), _define

_local = (ast) ->
  if not ast.value
    esnode.declare 'var', [ _compile(ast.name) ]
  else
    esnode.declare 'var', [ _compile(ast.name) , _compile(ast.value) ]

register AST.get('local'), _local

_ref = (ast) ->
  if ast.value.type() == 'proxyval'
    _compile ast.value
  else if @isDefine
    esnode.funcall esnode.member(esnode.identifier('_module'), esnode.identifier('get')), 
      [ esnode.literal(ast.name.value) ]
  else
    _compile ast.name
  
register AST.get('ref'), _ref

_proxyval = (ast) ->
  res = 
    if typeof(ast.compiler) == 'function' or ast.compiler instanceof Function 
      ast.compiler()
    else if ast.compiler instanceof AST
      _compile ast.compiler
    else
      _compile ast.name
  res

register AST.get('proxyval'), _proxyval

_param = (ast) ->
  _compile ast.name

register AST.get('param'), _param 

_procedure = (ast) ->
  name = if ast.name then _compile(ast.name) else null
  func = esnode.function name, (_compile(param) for param in ast.params), _compile(ast.body)
  maker = esnode.member(esnode.identifier('_rt'), esnode.identifier('proc'))
  esnode.funcall maker, [ func ]

register AST.get('procedure'), _procedure

_task = (ast) ->
  name = if ast.name then _compile(ast.name) else null
  esnode.function name, (_compile(param) for param in ast.params), _compile(ast.body)

register AST.get('task'), _task

_if = (ast) ->
  esnode.if _compile(ast.cond), _compile(ast.then), _compile(ast.else)

register AST.get('if'), _if

_funcall = (ast) ->
  esnode.funcall _compile(ast.funcall), (_compile(arg) for arg in ast.args)

register AST.get('funcall'), _funcall
register AST.get('taskcall'), _funcall

_return = (ast) ->
  esnode.return _compile(ast.value) 

register AST.get('return'), _return 

_binary = (ast) ->
  esnode.binary ast.op, _compile(ast.lhs), _compile(ast.rhs)
  
register AST.get('binary'), _binary

_throw = (ast) ->
  esnode.throw _compile(ast.value)

register AST.get('throw'), _throw 

_catch = (ast) ->
  esnode.catch _compile(ast.param), _compile(ast.body)
  
_finally = (ast) ->
  _compile ast

_try = (ast) ->
  esnode.try _compile(ast.body), (_catch(exp) for exp in ast.catches), if ast.finally then _finally(ast.finally) else null

register AST.get('try'), _try

_toplevel = (ast) ->
  imports = esnode.array(_importSpec(imp) for imp in ast.imports)
  params = 
    [ _compile(ast.moduleParam) ].concat(_importID(imp) for imp in ast.imports).concat([ _compile(ast.callbackParam) ])
  proc = esnode.function null, params, _compile(ast.body)
  esnode.funcall esnode.member(esnode.identifier('_rt'), esnode.identifier('toplevel')),
    [ 
      imports 
      proc 
    ]

register AST.get('toplevel'), _toplevel

_module = (ast) ->
  imports = esnode.array(_importSpec(imp) for imp in ast.imports)
  params = 
    [ _compile(ast.moduleParam) ].concat(_importID(imp) for imp in ast.imports).concat([ _compile(ast.callbackParam) ])
  proc = esnode.function null, params, _compile(ast.body)
  esnode.funcall esnode.member(esnode.identifier('_rt'), esnode.identifier('module')),
    [
      _compile(ast.spec)
      imports
      proc
    ]

register AST.get('module'), _module

_importSpec = (ast) ->
  _compile ast.spec

_importID = (ast) ->
  _compile ast.idParam

_importBinding = (ast, binding) ->
  [ _compile(binding.as) , esnode.member(_importID(ast), _compile(binding.spec)) ]
  
_import = (ast) ->
  esnode.declare 'var', (_importBidning(ast, binding) for binding in ast.bindings)...

register AST.get('import'), _import  

_export = (ast) ->
  bindings = 
    for binding in ast.bindings 
      esnode.funcall esnode.member(esnode.identifier('_module'), esnode.identifier('export')), 
        [ 
          esnode.literal(binding.spec.value)
        ]
  esnode.block bindings

register AST.get('export'), _export

module.exports = 
  compile: compile
  register: register
  get: get
