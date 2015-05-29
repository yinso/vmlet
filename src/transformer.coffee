# our goal is to convert the transformation into something that handles things on a per-unit basis.
# for example - procedure is a complete transformation unit, but it can be embedded further within 
# the 

types = {}

class TransformResult
  constructor: (@ast, @bindings, @transformer) ->
  transform: () ->
    result = 
      if @bindings instanceof Array
        @transformer @ast, @bindings...
      else
        @transformer @ast, @bindings
    #console.log '-- T.transform', @ast, result
    result

class TransformClause
  constructor: (@matcher, @transformer) ->
  match: (ast) ->
    res = @matcher ast 
    if res 
      new TransformResult ast, res, @transformer
    else
      false

class Transformer 
  constructor: (@type) ->
    @inner = []
  register: (matcher, transformer) ->
    @inner.push new TransformClause(matcher, transformer)
  isType: (ast) ->
    ast instanceof AST
  match: (ast) ->
    for clause in @inner 
      res = clause.match ast
      if res 
        return res
      else
        continue
    false

register = (ast, match, transform) ->
  
  if not types.hasOwnProperty(ast)
    types[ast] = new Transformer(ast)
  transformer = types[ast]
  transformer.register match, transform

transform = (ast) ->
  if types.hasOwnProperty ast.type()
    trans = types[ast.type()]
    res = trans.match ast 
    if res 
      return res.transform()
    else
      ast
  else
    ast

module.exports = 
  transform: transform 
  register: register 

