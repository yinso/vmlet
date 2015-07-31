
AST = require './ast'

class IsTailRegistry
  @transform: (ast) -> 
    if not @reg 
      @reg = new @()
    @reg.transform ast 
  transform: (ast) -> 
    refs = []
    @run ast, refs 
    refs
  run: (ast, refs) -> 
    type = "_#{ast.type()}"
    if @[type]
      @[type](ast, refs)
    else
      throw new Error("isTail.unknown_type: #{ast.type()}")
  push: (refs, ast) ->
    if refs.indexOf(ast) == -1
      refs.push ast 
  _number: () ->
  _string: () ->
  _bool: () ->
  _null: () ->
  _unit: () -> 
  _member: () -> 
  _binary: () -> 
  _ref: (ast, refs) -> 
    if ast.value.type() == 'procedure'
      @push refs, ast
  _funcall: (ast, refs) -> 
    funcall = ast.funcall 
    # although this isn't something 
    if funcall.type() == 'ref'
      @_ref funcall, refs 
    else if funcall.type() == 'procedure'
      @push refs, funcall
  _if: (ast, refs) -> 
    @run ast.then, refs 
    @run ast.else, refs 
  _block: (ast, refs) -> 
    for item, i in ast.items 
      if i == ast.items.length - 1 
        @run item, refs 
  _procedure: (ast, refs) -> 
    @run ast.body, refs
  _return: (ast, refs) -> 
    @run ast.value, refs
  _try: (ast, refs) -> # try/catch isn't tail call optimizable... 

module.exports = IsTailRegistry
