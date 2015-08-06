AST = require './ast'
TR = require './trace'
CLONE = require './clone'

# we need to determine if we want to pull out a list of the function via lambda lifting... 
# in order to do lambda lifting, we need to determine what are the free variables (if any)...
# a free variables are variables that aren't defined within the function itself. 

class TcoRegistry 
  @transform: (ast, procs) -> 
    if not @reg 
      @reg = new @()
    @reg.transform ast, procs
  transform: (ast, procs) -> 
    label = AST.symbol('_label')
    base = @run ast, procs, label
    cases = 
      for proc in procs 
        @run proc.value, procs, label
    body = 
      AST.block [
        AST.local label, ast.name
        AST.while AST.bool(true), 
          AST.block [
            AST.switch label, cases.concat([ base ])
          ]
      ]
    AST.procedure ast.name, ast.params, body
  run: (ast, procs, label) -> 
    type = "_#{ast.type()}"
    if @[type]
      @[type](ast, procs, label)
    else
      throw new Error("SwitchCaseRegistry.unknown_type: #{ast.type()}")
  _number: (ast, procs, label) -> ast
  _string: (ast, procs, label) -> ast
  _bool: (ast, procs, label) -> ast
  _null: (ast, procs, label) -> ast 
  _unit: (ast, procs, label) -> ast 
  _binary: (ast, procs, label) -> ast 
  _member: (ast, procs, label) -> ast 
  _array: (ast, procs, label) -> ast
  _object: (ast, procs, label) -> ast
  _if: (ast, procs, label) -> 
    thenAST = @run ast.then, procs, label
    elseAST = @run ast.else, procs, label
    AST.if ast.cond, thenAST, elseAST 
  _block: (ast, procs, label) -> 
    items = 
      for item, i in ast.items 
        if i < ast.items.length - 1 
          item 
        else
          @run item, procs, label
    AST.block items 
  _return: (ast, procs, label) -> 
    AST.return @run ast.value, procs
  _procedure: (ast, procs, label) -> 
    # there are sure a lot of variables that are meant to be 
    name = 
      if ast.name.type() == 'ref'
        ast.name 
      else
        AST.ref(ast.name)
    newParams = 
      for param in ast.params 
        CLONE.transform param
    locals = 
      for param, i in ast.params 
        AST.local param.name, newParams[i].ref()
    body = 
      if ast.body.type() == 'block'
        AST.block locals.concat(ast.body.items)
      else
        AST.block locals.concat(ast.body)
    body = @run body, procs, label
    AST.case name, body
  _while: (ast, procs, label) -> 
    AST.while ast.cond, @run(ast.block, procs, label)
  _switch: (ast, procs, label) -> 
    AST.switch ast.cond, (@run(c, procs, label) for c in ast.cases)
  _case: (ast, procs, label) -> 
    AST.case ast.cond, @run(ast.exp, procs, label)
  _defaultCase: (ast, procs, label) -> 
    AST.defaultCase @run(ast, procs, label)
  _continue: (ast, procs, label) -> ast
  _break: (ast, procs, label) -> ast
  _funcall: (ast, procs, label) -> 
    # this is only reachable in the case of tail call...
    # we need to see if this is going to be in the listo f the items that are meant to be converted... 
    funcall = ast.funcall 
    # the funcall will likely be a reference... 
    if procs.indexOf(funcall) == -1 # doesn't exist... 
      funcall 
    else # this is a candidate for conversion. 
      proc = funcall.value # we assume this is a reference... 
      assigns = 
        for param, i in proc.params 
          AST.assign AST.ref(param.name, param), ast.args[i]
      gotoProc = 
        AST.assign label, proc.name 
      AST.block assigns.concat([ gotoProc , AST.break() ])
  

module.exports = TcoRegistry
