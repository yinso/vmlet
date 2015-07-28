AST = require './ast'
isTail = require './istail'
TR = require './trace'
HashMap = require './hashmap'
CLONE = require './clone'

class Environment 
  constructor: () -> 
    @inner = new HashMap()
  setProc: (proc) -> 
    @set proc.name, proc
  setRef: (ref) -> 
    @set ref, ref.value
  setDefine: (def) -> 
    @set def.name, def.value
  has: (ref) -> 
    @inner.has ref 
  set: (key, val) -> 
    @inner.set key, val
    @
  delete: (ref) -> 
    @inner.delete ref
  keys: () -> 
    @inner.keys()
  values: () -> 
    @inner.values()

normalize = (ast) -> 
  env = new Environment()
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

transform = (ast, env = new Environment()) -> 
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
  procs = env.values()
  proc = 
    if procs.length > 0 
      _combineProcs res, procs 
    else
      res 
  _transformTailcall proc  

_combineProcs = (ast, procs) -> 
  locals = []
  for proc in procs 
    if proc != ast 
      locals.push AST.local(proc.name, proc)
  body = 
    AST.block locals.concat(if ast.body.type() == 'block' then ast.body.items else [ ast.body ])
  CLONE.transform AST.procedure ast.name, ast.params, body

_extendProcParams = (ast) -> 
  # we are going to create a new set of params with same name but different symbols... 
  # let's 
  newParams = 
    for param in ast.params 
      param.clone AST.symbol(param.name.value + "$")
      #param.clone()
  locals = 
    for param, i in ast.params 
      AST.local param.name, newParams[i].ref()
  AST.procedure ast.name, newParams, 
    AST.block locals.concat(if ast.body.type() == 'block' then ast.body.items else [ ast.body ])

_transformTailcall = (ast) -> 
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
  env.values()

importDefines = (ast, filtered) -> 
  defines = 
    for proc in filtered 
      proc.local()
  body = 
    if ast.body.type() == 'block'
      AST.block defines.concat(ast.body.items)
    else
      AST.block defines.concat(ast.body)
  AST.procedure ast.name, ast.params, body

module.exports = 
  normalize: normalize
  