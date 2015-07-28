
AST = require './ast'

_types = {}

register = (ast, trans) -> 
  if _types.hasOwnProperty(ast.type)
    throw new Error("PROC.duplicate_type: #{ast.type}")
  _types[ast.type] = trans

get = (ast) -> 
  if _types.hasOwnProperty(ast.type())
    _types[ast.type()]
  else
    throw new Error("PROC.unknown_type: #{ast.type()}")

# this should return the list of final calls... 
transform = (ast, refs = []) -> 
  refs = []
  _trans ast, refs
  refs 

_trans = (ast, refs) -> 
  proc = get ast 
  proc ast, refs 

_scalar = (ast, refs) -> 
  
register AST.get('number'), _scalar
register AST.get('string'), _scalar
register AST.get('bool'), _scalar
register AST.get('null'), _scalar
register AST.get('unit'), _scalar
register AST.get('member'), _scalar
register AST.get('binary'), _scalar

_ref = (ast, refs) ->
  if ast.value.type() != 'proxyval' # this is the one that we know isn't a procedure!
    refs.push ast

register AST.get('ref'), _ref    

_funcall = (ast, refs) -> 
  # strike gold here... 
  funcall = ast.funcall 
  # although this isn't something 
  if funcall.type() == 'ref'
    _ref funcall, refs 
  else if funcall.type() == 'procedure'
    refs.push funcall 
  # we do not deal with other types for now... 

register AST.get('funcall'), _funcall

_if = (ast, refs) ->
  _trans ast.then, refs 
  _trans ast.else, refs 

register AST.get('if'), _if

_block = (ast, refs) -> 
  for item, i in ast.items 
    if i == ast.items.length - 1 
      _trans item, refs 

register AST.get('block'), _block 

_body = (ast, refs) -> 
  _trans ast.body, refs

register AST.get('procedure'), _body

_value = (ast, refs) -> 
  _trans ast.value , refs 

register AST.get('return'), _value

module.exports = 
  transform: transform
