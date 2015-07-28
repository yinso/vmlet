# tail is a very specific transformation
# tail recursion elimination (self-calling).
# 
AST = require './ast'
Environment = require './environment'
TR = require './trace'
REF = require './ref'
CLONE = require './clone'

# to convert a function into its recursion equivalent (we will handle declared self-recursion and mutual recursion at 
# this level, and no async tco elimination). it takes the following steps.
# 
# 0 - identify inner functions (these functions will call each other but won't go outside of the scope.).
# 1 - inner function parameter renaming (the inner functions ought to be adjusted accordingly).
# 2 - label (function name mapping renaming) - to make sure the label is unique.
# 3 - while(true) { switch (_label) { }} is the main body. Switch is used to simulate label & goto.
# 4 - inner function parameter lifting to above the while loop.
# 5 - inline the code block into the switch case statements - make sure it ends in continue (with every one of them), with the appropriate labels attached.
# 6 - convert the tail call (as long as it calls within the switch statement) into a variable & label assignment.
# 7 - the above works for any inner functions (any calls outside of the inner functions will not be converted).
# 8 - this will also work for mutual recursion - exactly the same structure. except we will create separate definitions
#     that pulls in the mutual recursion.
# 9 - this can also work for whole module recursion - just consider them as a humonguous case of functions...

# maybe I need to get rid of my reliance on REF now that I have removed checking against environment everywhere else but 
# resolver...

# a couple of problems... do I want to go ahead and normalize a simple funcall? 
# let's try it anyway so we can at least see that it works... 

# how do I solve this problem? 
# 

# it seems like we do not want to handle the transform for functions that are nested... 
# although some tail recursive functions might be written at a nested level... what to do here? 
# in order to handle all these things generally. 
# we will need to pull out all of the functions, and then try to figure out how they call each other. 
#
# for example, a nested function, unless being returned, will not be seen outside of the existing structure. 
# that means we ought to be able to make such determinations to see if t


transform = (ast) ->
  #console.log 'TRE.transform', ast 
  # first thing we need to do is to determine if which of the references are defined within the procedure itself. 
  res = isTailRecursive ast.body, ast
  refs = REF.transform ast
  #for ref in refs 
  #  if ref.value.type() == 'procedure'
  #    console.log '-- TCO.transform.ref.proc', ast.name, ref, ast.name == ref, ref.value
  #  else if ref.value.type() == 'proxyval' # this points to something extenral... 
  #    console.log '-- TCO.transform.ref.proxval', ast.name, ref
  if res 
    trans = tailRecursive(ast)
    trans
  else
    ast

tailRecursive = (proc) -> 
  labelVar = AST.symbol('label')
  labelName = proc.name.literal()
  labelDef = AST.local labelVar, labelName
  body = normalize proc.body , proc, labelVar
  whileBlock = AST.while AST.bool(true), 
    AST.block [
      AST.switch labelVar, [
        AST.case(labelName, body)
      ]
    ]
  proc.body = 
    AST.block [
      labelDef 
      whileBlock
    ]
  proc 

normalize = (ast, proc, labelVar) -> 
  switch ast.type()
    when 'block'
      items = 
        for item, i in ast.items 
          if i < ast.items.length - 1
            item 
          else
            normalize item, proc, labelVar 
      AST.block items 
    when 'return'
      value = normalize(ast.value, proc, labelVar)
      if value.type() == 'block'
        value 
      else
        AST.return value
    when 'if'
      thenAST = normalize ast.then, proc, labelVar 
      elseAST = normalize ast.else, proc, labelVar
      AST.if ast.cond, thenAST, elseAST 
    when 'funcall' # this is the fun part.
      funcall = ast.funcall 
      switch funcall.type()
        when 'ref'
          if funcall.value == proc
            _goto ast, proc, labelVar
          else
            ast
        else
          ast
    else # don't know what else would be here for now... so keep going!
      ast

_goto = (ast, proc, labelVar) -> 
  # func(arg1, ... )
  # ==> 
  # p1 = arg1
  # p2 = arg2 ... 
  # label = "funcName"
  # continue
  labelName = proc.name.literal()
  items = []
  tempVars = 
    for param, i in proc.params 
      CLONE.transform param.name
  for arg, i in ast.args 
    items.push AST.local(tempVars[i], arg)
  for arg, i in ast.args 
    items.push AST.assign(proc.params[i].ref(), tempVars[i])
  items.push AST.assign(labelVar, labelName)
  items.push AST.break()
  AST.block items

isTailRecursive = (ast, proc) ->
  switch ast.type()
    when 'block'
      if ast.items.length == 0 
        false
      else
        isTailRecursive ast.items[ast.items.length - 1], proc
    when 'if'
      isTailRecursive(ast.then, proc) or isTailRecursive(ast.else, proc)
    when 'return'
      isTailRecursive ast.value, proc
    when 'funcall'
      funcall = ast.funcall 
      switch funcall.type()
        when 'ref'
          return funcall.value == proc
        when 'symbol'
          return funcall == proc.name
        else
          return false
    else
      false

isTailCall = (ast, proc) ->
  switch ast.type()
    when 'procedure'
      isTailCall ast.body
    when 'block'
      isTailCall ast.items[ast.items.length - 1]
    when 'return'
      isTailCall ast.value
    when 'funcall'
      # when we get here we now need to determine if it's calling a function that's defined within the scope of the 
      # module... 
      # this is the important part... 
      # 1) defined within the function.
      # 2) defined within the module 
      # 3) defined outside of the module. 
      funcall = ast.funcall
      true
    when 'if' # only one of them needs to be 
      isTailCall(ast.then) or isTailCall(ast.else)
    else
      false

determineRefLocation = (ast) -> 
  # how do we determine ref location? have we been tracking them as we go? 
  

normalizeRefs = (ast) -> 
  # we are dealing with a procedure, so we have to deal with the 
  
  
module.exports = 
  transform: transform

