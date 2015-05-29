# transformer for local.

# let's have this being for transforming just the LOCAL sentence... yes, let's make it very similar to macro.

AST = require './ast'

types = {}

register = (ast, transformer) ->
  if types.hasOwnProperty(ast.type)
    throw errorlet.create {error: 'CPS.duplicate_ast_type', type: ast.type}
  else
    types[ast.type] = transformer
  
get = (ast) ->
  if types.hasOwnProperty(ast.type())
    types[ast.type()]
  else
    throw errorlet.create {error: 'CPS.unsupported_as_type', type: ast}

transform = (ast) ->
  transformer = get ast 
  transformer ast 

transformScalar = (ast) ->
  ast 

register AST.get('number'), transformScalar
register AST.get('bool'), transformScalar
register AST.get('null'), transformScalar
register AST.get('symbol'), transformScalar
register AST.get('string'), transformScalar
register AST.get('binary'), transformScalar
register AST.get('member'), transformScalar
register AST.get('procedure'), transformScalar
register AST.get('proxyval'), transformScalar
register AST.get('ref'), transformScalar
register AST.get('funcall'), transformScalar
register AST.get('array'), transformScalar
register AST.get('object'), transformScalar

transformBlock = (ast) ->
  items = []
  for item, i in ast.items 
    items.push transform item 
  AST.block items 

register AST.get('block'), transformBlock

transformLocal = (ast) ->
  val = transform ast.normalized()
  ast.clone val 

register AST.get('local'), transformLocal

transformIf = (ast) ->
  

module.exports = 
  transform: transform 
  register: register
