loglet = require 'loglet'
Promise = require './promise'
Frame = require './frame'
Environment = require './environment'
errorlet = require 'errorlet'
CodeBlock = require './codeblock'
Procedure = require './procedure'
baseEnv = require './baseenv'

class Task
  constructor: (@codeBlock, @env = new Environment()) ->
    #loglet.log 'Task.ctor', @env == baseEnv, @codeBlock
    @pushFrame @codeBlock
    @running = true
  isRunning: () ->
    @running
  suspend: () ->
    @running = false
  resume: () ->
    @running = true
    @runLoop()
  pushFrame: (code) ->
    @top = new Frame code, @top, @
    #loglet.log '==> pushFrame ==>', code
  popFrame: (val) ->
    #loglet.log '<== popFrame <==', @top.prev != null
    if @top.prev
      @top = @top.prev
      @top.push val
      if @hasError()
        @top.throw @error
    else
      @top.throw errorlet.create {error: 'Task.popFrame:call_stack_underflow'}
  runLoop: () ->
    # we need a way to *auto-pop* frame at the end of the OPCODE (but not while it pushes things).
    # incIP() is too simplistic, although it's arguably a good way.
    # but what we need is a way to handle both incIP() & pushFrame at the same time so we won't *pop*.
    # we can pass in 
    while (@isRunning() and (opcode = @top.current()))
      try 
        opcode.run @top
        #loglet.log opcode, @top.stack
      catch e 
        @top.throw e
    if @isRunning()
      try 
        @resolve @top.pop()
      catch e 
        @top.throw e
  run: (@cb) ->
    @setupPromise @cb
    @runLoop()
  setupPromise: (cb) ->
    @deferred = Promise.defer()
    @deferred
      .promise
      .then (v) ->
        cb null, v
      .catch (e) ->
        cb e
  # error handling related functions...
  setError: (e) ->
    @error = e
  hasError: () ->
    @hasOwnProperty('error')
  popError: () ->
    e = @error
    delete @error
    e
  resolve: (v) ->
    if @running
      @running = false
      @deferred.resolve v
  reject: (e) ->
    if @running
      @running = false
      @deferred.reject e

AST = require './ast'
compiler = require './compiler'

oldCompileProc = compiler.get AST.get('proc')

compileProcedure = (ast, env, code, isTail) ->
  loglet.log 'compileProcedure.called'
  res = oldCompileProc ast, env, new CodeBlock(), isTail
  proc = makeProcedure res.items[0].push
  code.push(proc)

#compiler.override AST.get('proc'), compileProcedure

makeProcedure = (proc) ->
  outer = (args..., cb) ->
    if not (typeof(cb) == 'function' or cb instanceof Function)
      args.push cb
      cb = (err, res) -> 
        if err
          loglet.error err
        else
          loglet.log res
    code = new CodeBlock()
    for arg in args 
      code.push arg
    code.push(proc).funcall(args.length)
    task = new Task code
    task.run cb
  outer.__vmlet = {procedure: proc}
  outer
  


module.exports = Task
