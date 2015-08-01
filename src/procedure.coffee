AST = require './ast'
isTail = require './istail'
TR = require './trace'
CLONE = require './clone'
TCO = require './goto'
Environment = require './symboltable'

normalize = (ast) -> 
  env = Environment.make({newSym: false})
  defines = getDefines ast, env
  results = 
    for def in defines 
      transform(def.value) 
  # how to assign back to the values? 
  for def, i in defines 
    def.value = results[i]
  results

getDefines = (ast, env) -> 
  items = 
    switch ast.body.type()
      when 'block'
        ast.body.items
      else
        [ ast.body ]
  results = []
  for item, i in items
    switch item.type()
      when 'define', 'local'
        if item.value.type() == 'procedure'
          env.setDefine item
          results.push item
  results

# in order to implement lambda lifting - we would need to determine which 
# variables are 

transform = (ast, env = Environment.make()) -> 
  # what do we want to do? return two values. 
  # 1 value tells us if we have a tail call. 
  # 2nd value gives us a set of recursions... 
  # we want to separate them from the ones that need to be transformed??... is that the idea? 
  # what does it mean for self-recursion? 
  # in a self-recursion, we are dealing with the 
  # at the end we want to determine if we want to go onto transforming this particular function... 
  res = _findTailCallProcs ast, env
  if not res 
    return ast
  procs = env.keys()
  _transformTailCall res , procs

_transformTailCall = (ast, procs) -> 
  res = TCO.transform ast, procs
  TR.log '--transform.tail.call', ast.name, res
  ast

# we want to track stack?? I think that's the idea... 
_findTailCallProcs = (ast, env, stack = [ ast ]) -> 
  refs = isTail.transform ast
  if refs.length > 0 # greater than zero.
    defines = getDefines ast, env 
    filtered = filterDefines ast, refs, env
    for proc in filtered 
      if stack.indexOf(proc) == -1
        _findTailCallProcs proc, env, stack.concat(filtered)
    ast
  else
    null

filterDefines = (ast, refs, env) -> 
  for ref in refs
    if env.has ref 
      env.delete ref 
    else
      env.setRef ref 
  env.values() # get back the refs? 

module.exports = 
  normalize: normalize
  