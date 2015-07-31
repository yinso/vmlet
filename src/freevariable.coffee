AST = require './ast'
Environment = require './environment'
TR = require './trace'

class FreeVariable
  @transform: (ast, env) -> 
    if not @reg 
      @reg = new @()
    @reg.transform ast, env
  transform: (ast, env) -> 
    if ast.type() != 'procedure'
      throw new Error("FreeVariable.not_a_procedure: #{ast.type()}")
    # I can pass in procs or just pass in a list of the defined 
    refs = []
    @run ast.body, env, refs
    # we cannot determine the call sites with this function... that needs to be done elsewhere... 
    # a global sweep wouldn't be that hard...? 
    results = []
    for ref in refs 
      if not ref.equals(ast.name)
        results.push ref
    results
  run: (ast, env, refs) -> 
    type = "_#{ast.type()}"
    if @[type]
      @[type] ast, env , refs
    else
      throw new Error("FreeVariable.unknown_type: #{ast.type()}")
  _number: (ast, env, refs) -> 
  _string: (ast, env, refs) -> 
  _bool: (ast, env, refs) -> 
  _null: (ast, env, refs) -> 
  _unit: (ast, env, refs) -> 
  _symbol: (ast, env, refs) -> 
    isFree = env.isFreeVariable ast
    if isFree 
      ref = env.get ast
      TR.log '-- FreeVariable.has_free_variable', ast, ref, env
      refs.push ref
  _ref: (ast, env, refs) -> 
    @_symbol ast.name, env, refs 
  _block: (ast, env, refs) -> 
    for item, i in ast.items 
      @run item, env, refs 
  _if: (ast, env, refs) -> 
    @run ast.cond, env, refs 
    @run ast.then, env, refs 
    @run ast.else, env, refs 
  _binary: (ast, env, refs) -> 
    @run ast.lhs, env, refs 
    @run ast.rhs, env, refs 
  _member: (ast, env, refs) -> 
    @run ast.head, env, refs 
  _return: (ast, env, refs) -> 
    @run ast.vaue, env, refs
  _define: (ast, env, refs) -> 
    @run ast.value, env, refs
  _assign: (ast, env, refs) -> 
    @run ast.name, env, refs 
    @run ast.value, env, refs 
  _local: (ast, env, refs) -> 
    @run ast.value, env, refs
  _funcall: (ast, env, refs) -> 
    # funcall is a way to see if we have a call site ??? but we are probably not going to do so here... 
    @run ast.funcall, env, refs
    for arg in ast.args 
      @run arg, env, refs
  _taskcall: (ast, env, refs) -> 
    # funcall is a way to see if we have a call site ??? but we are probably not going to do so here... 
    @run ast.funcall, env, refs
    for arg in ast.args 
      @run arg, env, refs
  _procedure: (ast, env, refs) -> 
    # every inner procedure should already have this done so we can ignore
    # what we are looking for here are free variables that are referred within the current block... 
    # one thing that ought to be tracked might be the environment? as is we have no way of knowing 
    # what the environments are at any given time... hmmm.... 
  _task: (ast, env, refs) -> 
  _while: (ast, env, refs) -> 
    @run ast.cond, env, refs 
    @run ast.block, env, refs 
  _switch: (ast, env, refs) -> 
    @run ast.cond, env, refs 
    for c in ast.cases 
      @run c, env, refs 
  _case: (ast, env, refs) -> 
    @run ast.cond, env, refs 
    @run ast.exp, env, refs 
  _defaultCase: (ast, env, refs) -> 
    @run ast.exp, env, refs 
  _continue: (ast, env, refs) -> 
  _break: (ast, env, refs) -> 


module.exports = FreeVariable 

  