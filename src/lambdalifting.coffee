# lifting lambda... seems like something that ought to be done as a global transformation. 

# 1 - this is similar to ANF... but we will attach to the top level.... 
# if it's 
# 

Environment = require './environment'
AST = require './ast'

class LambdaLifting
  @transform: (ast, env) -> 
    if not @reg 
      @reg = new @()
    @reg.transform ast, env
  transform: (ast, env) -> 
    # what are we going to do? 
  run: (ast, env) -> 
  _number: (ast, env) -> ast 
  _string: (ast, env) -> ast
  _bool: (ast, env) -> ast 
  _null: (ast, env) -> ast 
  _unit: (ast, env) -> ast 

module.exports = LambdaLifting

  
    
