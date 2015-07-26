# we need to determine how to pull out the references from within the code, we also need to verify whether it's 
# defined here or externally. 
# 
# a proxyval will be an external reference - inter-module. 
# another approach would be to tag the source location against the refs so we know which particular modules 
# they come from.

# in many ways 

AST = require './ast'

_types = {}

register = (ast, trans) -> 
  if _types.hasOwnProperty(ast.type)
    throw new Error("ref.duplicate_type: #{ast.type}")
  _types[ast.type] = trans 

get = (ast) -> 
  if _types.hasOwnProperty(ast.type())
    _types[ast.type()]
  else
    throw new Error("ref.invalid_type: #{ast.type()}")

transform = (ast) -> 
  refs = []
  _trans ast , refs
  refs 

_trans = (ast, refs) -> 
  trans = get ast
  trans ast, refs 

_scalar = (ast, refs) -> 

register AST.get('number'), _scalar
register AST.get('bool'), _scalar
register AST.get('string'), _scalar
register AST.get('null'), _scalar
register AST.get('unit'), _scalar
register AST.get('symbol'), _scalar
register AST.get('continue'), _scalar
register AST.get('break'), _scalar

_ref = (ast, refs) -> 
  if refs.indexOf(ast) == -1
    refs.push ast 

register AST.get('ref'), _ref 

_binary = (ast, refs) -> 
  _trans ast.lhs, refs
  _trans ast.rhs, refs

register AST.get('binary'), _binary

_member = (ast, refs) -> 
  _trans ast.head, refs

register AST.get('member'), _member

_if = (ast, refs) -> 
  _trans ast.cond, refs 
  _trans ast.then, refs 
  _trans ast.else, refs

register AST.get('if'), _if 

_define = (ast, refs) -> 
  if ast.value 
    _trans ast.value, refs
  
register AST.get('define'), _define
register AST.get('local'), _define
register AST.get('assign'), _define

_proc = (ast, refs) -> 
  _trans ast.body, refs 

register AST.get('procedure'), _proc
register AST.get('task'), _proc
register AST.get('module'), _proc
register AST.get('toplevel'), _proc
register AST.get('catch'), _proc

_funcall = (ast, refs) -> 
  _trans ast.funcall, refs 
  for arg in ast.args
    _trans arg, refs 

register AST.get('funcall'), _funcall
register AST.get('taskcall'), _funcall

_block = (ast, refs) -> 
  for item, i in ast.items 
    _trans item, refs 

register AST.get('block'), _block

_try = (ast, refs) -> 
  _trans ast.body, refs 
  for c in ast.catches
    _trans c, refs 
  if ast.finally
    _trans ast.finally, refs

register AST.get('try'), _try 

_return = (ast, refs) -> 
  _trans ast.value, refs

register AST.get('return'), _return 

_while = (ast, refs) -> 
  _trans ast.cond, refs 
  _trans ast.block, refs

register AST.get('while'), _while 

_switch = (ast, refs) -> 
  _trans ast.cond, refs 
  for c in ast.cases 
    _trans c, refs

register AST.get('switch'), _switch

_case = (ast, refs) -> 
  _trans ast.cond, refs 
  _trans ast.exp, refs 

register AST.get('case'), _case

_defaultCase = (ast, refs) -> 
  _trans ast.exp, refs

register AST.get('defaultCase'), _defaultCase

module.exports = 
  transform: transform 
  register: register 
  
