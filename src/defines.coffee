AST = require './ast'
Env = require './environment'
TR = require './trace'

_types = {}

register = (ast, trans) -> 
  if _types.hasOwnProperty(ast.type)
    throw new Error("DEFINE.duplicate_type: #{ast.type}")
  _types[ast.type] = trans 

get = (ast) -> 
  if _types.hasOwnProperty(ast.type())
    _types[ast.type()]
  else
    throw new Error("DEFINE.invalid_type: #{ast.type()}")

transform = (ast) -> 
  defines = []
  _trans ast, defines
  defines

_trans = (ast, defines) ->
  proc = get ast 
  proc ast, defines

_toplevel = (ast, defines) ->
  

_scalar = (ast) -> 

register AST.get('number'), _scalar
register AST.get('string'), _scalar
register AST.get('bool'), _scalar
register AST.get('null'), _scalar
register AST.get('unit'), _scalar
register AST.get('symbol'), _scalar
register AST.get('ref'), _scalar
register AST.get('binary'), _scalar
register AST.get('funcall'), _scalar
register AST.get('taskcall'), _scalar
register AST.get('import'), _scalar
register AST.get('export'), _scalar
register AST.get('break'), _scalar
register AST.get('continue'), _scalar

_if = (ast, defines) -> 
  _trans ast.then, defines
  _trans ast.else, defines

register AST.get('if'), _if

_member = (ast, defines) -> 
  _trans ast.head, defines

register AST.get('member'), _member

_body = (ast, defines) -> 
  _trans ast.body, defines

register AST.get('toplevel'), _body
register AST.get('module'), _body
register AST.get('procedure'), _body
register AST.get('task'), _body
register AST.get('catch'), _body

_block = (ast, defines) -> 
  for item, i in ast.items 
    _trans item , defines

register AST.get('block'), _block

_value = (ast, defines) -> 
  _trans ast.value , defines

register AST.get('return'), _value 
register AST.get('assign'), _value 

_define = (ast, defines) -> 
  _trans ast.value, defines
  if defines.indexOf(ast) == -1
    defines.push ast
  
register AST.get('define'), _define
register AST.get('local'), _define

_try = (ast, defines) -> 
  _trans ast.body, defines
  for c in ast.catches 
    _trans c, defines 
  if ast.finally 
    _trans ast.finally, defines

register AST.get('try'), _try

_while = (ast, defines) -> 
  _trans ast.block, defines 

register AST.get('while'), _while

_switch = (ast, defines) -> 
  for c in ast.cases
    _trans c, defines 

register AST.get('switch'), _switch

_case = (ast, defines) -> 
  _trans ast.exp, defines

register AST.get('case'), _case
register AST.get('defaultCase'), _case

module.exports = 
  register: register 
  transform: transform 