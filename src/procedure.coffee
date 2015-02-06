CodeBlock = require './codeblock'
ParameterList = require './parameter'
Opcode = require './opcode'
Environment = require './environment'
baseEnv = require './baseenv'
loglet = require 'loglet'

class Procedure extends CodeBlock
  @makeParams: (params = []) ->
    ParameterList.make params
  @makeParam: (args...) ->
    ParameterList.makeParam args...
  @makeFrameProc = (proc) ->
    proc.__vmlet.frameProc = true
    proc
  @make: (args...) ->
    inner = new @ args...
    outer = (args..., cb) ->
      code = new CodeBlock()
      for arg in args
        code.push arg
      code.push(inner).funcall(args.length)
      # we don't have reference to the task object!
      new Task code, cb
    outer.__vmlet = { procedure: inner }
    outer
  constructor: (@name, @params, body = null, @returns = null) ->
    if body
      @setBody body
  setBody: (body) ->
    @items = body.items
    @catch = body.catch
    @finally = body.finally
    @length = body.length
  inspect: () ->
    @toString()
  toString: () ->
    buffer = []
    if @name
      buffer.push @name
    buffer.push @params.toString()
    buffer.push @items.toString()
    '#{func ' + buffer.join(' ') + '}'
  normalizeArguments: (args) ->
    @params.normalize args

Opcode.register 'param', class ParamOpCode extends Opcode
  constructor: (@type) ->
  run: (frame) ->
    args = frame.popN @type
    frame.push ParameterList.makeParam args...
    frame.incIP()
  equals: (op) ->
    op instanceof ParamOpcode and @type == op.type
  toString: () ->
    "[param #{@type}]"

Opcode.register 'paramList', class ParamListOpcode extends Opcode
  constructor: (@count) ->
  run: (frame) ->
    params = frame.popN @count
    frame.push ParameterList.make params
    frame.incIP()
  equals: (op) ->
    op instanceof ParamListOpcode and @count == op.count
  toString: () ->
    "[paramList #{@count}]"

Opcode.registerSingleton 'procedure', class ProcedureOpcode extends Opcode
  run: (frame) ->
    [ name , params , body ] = frame.popN 3 # name, signature, # body.
    frame.push new Procedure(name, params, body) # this will automatically makes it a closure.
    frame.incIP()
  toString: () ->
    '[procedure]'

Opcode.register 'funcall', class FuncallOpcode extends Opcode
  constructor: (@count) ->
  run: (frame) ->
    proc = frame.pop()
    args = frame.popN @count
    @_run frame, proc, args
  _run: (frame, proc, args) ->
    if proc instanceof Procedure
      @_runProcedure frame, proc, args
    else if typeof(proc) == 'function' or proc instanceof Function
      if proc.__vmlet?.procedure instanceof Procedure
        @_runProcedure frame, proc.__vmlet.procedure, args
      else if proc.__vmlet?.frameFunc
        proc frame, args...
      else
        frame.push proc(args...)
        frame.incIP()
    else
      frame.throw errorlet.create {error: 'not_a_procedure', procedure: proc}
  _runProcedure: (frame, proc, args) ->
    frame.task.pushFrame proc
    frame.task.top.pushArguments proc.normalizeArguments(args)
    frame.incIP(1, false) # this can cause things to step off the ledge and we don't want that.
  equals: (op) ->
    op instanceof FuncallOpcode and @count == op.count
  toString: () ->
    "[funcall #{@count}]"

Opcode.register 'tailcall', class TailcallOpcode extends FuncallOpcode
  _runProcedure: (frame, proc, args) ->
    if frame.prev
      frame.task.popFrame()
    frame.task.pushFrame proc
    frame.task.top.pushArguments proc.normalizeArguments args
    frame.incIP(1, false) 
  equals: (op) ->
    op instanceof TailcallOpcode and @count == op.count
  toString: () ->
    "[tailcall #{@count}]"

Opcode.registerSingleton 'apply', class ApplyOpcode extends FuncallOpcode
  run: (frame) ->
    proc = frame.pop()
    args = frame.pop()
    if not args instanceof Array
      return frame.throw errorlet.create {error: 'opcode_apply_args_must_be_array', args: args}
    @_run frame, proc, args
  toString: () ->
    '[apply]'

Opcode.registerSingleton 'trace', class TraceOpcode extends Opcode
  run: (frame) ->
    proc = frame.pop()
    if proc.__vmlet
      proc.__vmlet.trace = true
    else
      proc.__vmlet = { trace: true }
    frame.push undefined
    frame.incIP()
  toString: () ->
    '[trace]'

CodeBlock::trace = () ->
  @add 'trace'

# trace function.
baseEnv.define 'trace', new Procedure 'trace', 
  ParameterList.make([ParameterList.makeParam('f')]),
  new CodeBlock()
    .ref('f')
    .trace()

Opcode.registerSingleton 'untrace', class UnTraceOpcode extends Opcode
  run: (frame) ->
    proc = frame.pop()
    # this function should now be able to be traced...
    if proc.__vmlet
      delete proc.__vmlet.trace 
    frame.push undefined
    frame.incIP()
  toString: () ->
    '[untrace]'

CodeBlock::untrace = () ->
  @add 'untrace'

baseEnv.define 'untrace', new Procedure 'untrace',
  ParameterList.make([ParameterList.makeParam('f')]),
  new CodeBlock()
    .ref('f')
    .untrace()

Opcode.registerSingleton 'showEnv', class ShowEnvOpcode extends Opcode
  run: (frame) ->
    frame.task.env.show()
    frame.push undefined 
    frame.incIP()

CodeBlock::showEnv = () ->
  @add 'showEnv'

baseEnv.define 'showEnv', new Procedure 'showEnv',
  ParameterList.make(),
  new CodeBlock()
    .showEnv()

fib2 = (n) ->
  if n <= 0
    0
  else if n <= 2
    1
  else 
    fib2(n - 1) + fib2(n - 2)

baseEnv.define 'fib2', fib2


module.exports = Procedure
