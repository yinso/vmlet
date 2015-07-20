# tail is a very specific transformation
# tail recursion elimination (self-calling).
# 
AST = require './ast'

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

transform = (ast) ->
  console.log 'TRE.transform', ast 
  ast
  
module.exports = 
  transform: transform

