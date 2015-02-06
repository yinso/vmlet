errorlet = require 'errorlet'
loglet = require 'loglet'
CodeBlock = require './codeblock'
Promise = require './promise'
Environment = require './environment'
Procedure = require './procedure'

class Frame
  constructor: (code, @prev, @task) ->
    @code = CodeBlock.make code
    @env = @task.env
    @stack = []
    @onThrowLabelStack = []
    @lexicals = [] # a list of lexical references.
    @dynamics = [] # a list of dynamic variables - they should be named...
    @ip = 0 
    paused = false
  clone: () ->
    frame = new Frame @code, @prev, @task
    frame.stack = [].concat @stack
    frame.current = @current
  isPaused: () ->
    @paused
  current: () ->
    @code.items[@ip]
  incIP: (count = 1, toReturn = true) ->
    @ip += count
    if @ip >= @code.length and toReturn
      #loglet.log '++++++++++++++++++++++ Frame.incIP_to_return', @ip, @code, @code.length
      # it is time to pop the current frame via return.
      @return()
  jump: (count) ->
    @incIP count + 1
  ref: (key) ->
    @env.get key
  push: (val) ->
    self = @
    if val instanceof Promise
      @task.suspend()
      p = 
        val
          .then (v) ->
            self.popIfEqual(p)
            self.push v
            self.task.resume()
          .catch (e) ->
            self.popIfEqual p
            self.task.resume()
            self.throw e
      @stack.push p
    else
      @stack.push val
  pushArguments: (args) ->
    @env = new Environment args, @env
  pushThrowLabel: (label) ->
    @onThrowLabelStack.push label
  popThrowLabel: () ->
    @onThrowLabelStack.pop()
  hasThrowLabel: () ->
    @onThrowLabelStack.length > 0
  throw: (e) ->
    if @hasThrowLabel()
      @task.setError e
      label = @popThrowLabel()
      @goto label
    else if @task.top.prev # nothing here to handle the error... so we will unwind the stack.
      @task.popFrame()
      @task.top.throw e
    else # finally return the error if there are nothing more to unwind...
      @task.reject e
  getLexical: (id) ->
    loglet.log 'Frame.getLexical', id.name, @lexicals[id.name], @lexicals
    @lexicals[id.name]
  setLexical: (id, val) ->
    @lexicals[id] = val
  isTail: () ->
    @ip == @code.items.length - 1
  isEmpty: () ->
    @stack.length <= 0
  top: () ->
    @stack[@stack.length - 1]
  pop: () ->
    if @stack.length <= 0
      @throw errorlet.create {error: 'Frame.pop:data_stack_underflow'}
    else
      @stack.pop()
  popN: (count = 1) ->
    #loglet.log '__frame.popN.stack', count, @stack
    if @stack.length < count
      @throw errorlet.create {error: 'Frame:popN:data_stack_underflow', stack: @} 
    else
      @stack.splice @stack.length - count, count
  popIfEqual: (v) ->
    #loglet.log '__frame.popIfEqual', v, @stack
    if @stack.length > 0 and @stack[@stack.length - 1] == v
      @pop()
  pushEnv: () ->
    @env = new Environment @env
  popEnv: () ->
    @env = @env.prev
  goto: (label) ->
    @ip = @code.findLabel label
  return: () ->
    try 
      #loglet.log '=========== Frame.return =============', @stack, @prev instanceof Frame
      result = @pop()
      if @prev instanceof @constructor
        @prev.push result
        @task.top = @prev
        if @task.top.ip >= @task.top.code.length
          @task.top.return()
      else # we have to return the result back to to task itself...
        # hmm...
        @task.resolve result
    catch e
      @task.throw e

module.exports = Frame
