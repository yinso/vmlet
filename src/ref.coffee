# we need to determine how to pull out the references from within the code, we also need to verify whether it's 
# defined here or externally. 
# 
# a proxyval will be an external reference - inter-module. 
# another approach would be to tag the source location against the refs so we know which particular modules 
# they come from.

# in many ways 

AST = require './ast'
TR = require './trace'

class Ref
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
      @[type] ast, refs
    else
      throw new Error("Ref.unknown_ast: #{ast.type()}")
  _number: (ast, refs) -> 
  _string: (ast, refs) -> 
  _bool: (ast, refs) -> 
  _null: (ast, refs) -> 
  _unit: (ast, refs) -> 
  _symbol: (ast, refs) -> 
  _continue: (ast, refs) -> 
  _break: (ast, refs) -> 
  _ref: (ast, refs) -> 
    if refs.indexOf(ast) == -1 
      refs.push ast 
  _binary: (ast, refs) -> 
    @run ast.lhs, refs
    @run ast.rhs, refs
  _member: (ast, refs) -> 
    @run ast.head, refs
  _if: (ast, refs) -> 
    @run ast.cond, refs 
    @run ast.then, refs 
    @run ast.else, refs
  _define: (ast, refs) -> 
    if ast.value 
      @run ast.value, refs
  _local: (ast, refs) -> 
    if ast.value 
      @run ast.value, refs
  _assign: (ast, refs) -> 
    if ast.value 
      @run ast.value, refs
  _procedure: (ast, refs) -> 
    @run ast.body, refs 
  _task: (ast, refs) -> 
    @run ast.body, refs 
  _module: (ast, refs) -> 
    @run ast.body, refs 
  _toplevel: (ast, refs) -> 
    @run ast.body, refs 
  _funcall: (ast, refs) -> 
    @run ast.funcall, refs 
    for arg in ast.args
      @run arg, refs 
  _taskcall: (ast, refs) -> 
    @run ast.funcall, refs 
    for arg in ast.args
      @run arg, refs 
  _block: (ast, refs) -> 
    for item, i in ast.items 
      @run item, refs 
  _catch: (ast, refs) -> 
    @run ast.body, refs
  _try: (ast, refs) -> 
    @run ast.body, refs 
    for c in ast.catches
      @run c, refs 
    if ast.finally
      @run ast.finally, refs
  _return: (ast, refs) -> 
    @run ast.value, refs
  _while: (ast, refs) -> 
    @run ast.cond, refs 
    @run ast.block, refs
  _switch: (ast, refs) -> 
    @run ast.cond, refs 
    for c in ast.cases 
      @run c, refs
  _case: (ast, refs) -> 
    @run ast.cond, refs 
    @run ast.exp, refs 
  _defaultCase: (ast, refs) -> 
    @run ast.exp, refs

module.exports = Ref


