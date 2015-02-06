errorlet = require 'errorlet'
loglet = require 'loglet'
Promise = require './promise'

class Opcode
  @opcodes = {}
  @singles = {}
  @registerSingleton: (name, type) ->
    @register name, type
    @singles[name] = new type()
  @register: (key, opcode) ->
    @opcodes[key] = opcode
    opcode
  @get: (key) ->
    @opcodes[key]
  @make: (key, args...) ->
    if @singles.hasOwnProperty(key)
      @singles[key]
    else if @opcodes.hasOwnProperty(key)
      opcodeClass = @opcodes[key]
      new opcodeClass args...
    else
      error = errorlet.create {error: 'unknown_opcode', key: key}
      loglet.error error
      throw error
  run: (frame) ->
    frame.incIP()
  equals: (op) ->
    op == @
  inspect: () ->
    @toString()

Opcode.registerSingleton 'begin', class BeginOpcode extends Opcode
  run: (frame) ->
    frame.push @
    frame.incIP()
  toString: () ->
    '[begin]'

Opcode.registerSingleton 'end', class EndOpcode extends Opcode
  run: (frame) ->
    frame.incIP()
  toString: () ->
    '[end]'

Opcode.register 'push', class PushOpcode extends Opcode
  constructor: (@push) ->
  run: (frame) ->
    frame.push @push
    frame.incIP()
  equals: (op) ->
    if not op instanceof PushOpcode
      return false
    if @push == op.push
      return true
    if @push instanceof Object and op.push instanceof Object
      if @push.constructor.prototype.equals
        return @push.equals op.push
      else
        return false
    else
      false
  toString: () ->
    "[push #{@push}]"

Opcode.register 'popN', class PopOpcode extends Opcode
  constructor: (@count) ->
  run: (frame) ->
    args = frame.popN @count
    frame.incIP()
    args
  equals: (op) ->
    op instanceof PopOpcode and @count == op.count
  toString: () ->
    "[pop #{@count}]"

Opcode.register 'array', class ArrayOpCode extends Opcode
  constructor: (@count) ->
  run: (frame) ->
    ary = frame.popN @count
    frame.push ary
    frame.incIP()
  toString: () ->
    "[array #{@count}]"

Opcode.register 'object', class ObjectOpCode extends Opcode
  constructor: (@count) ->
    if @count %2 != 0
      throw errorlet.create {error: 'object_count_must_be_factor_of_2', count: @count}
  run: (frame) ->
    keyvals = frame.popN @count
    frame.push @keyValsToObject(keyvals)
    frame.incIP()
  keyValsToObject: (keyvals) ->
    obj = {}
    for i in [0...keyvals.length] by 2
      key = keyvals[i]
      val = keyvals[i + 1]
      obj[key] = val
    obj
  toString: () ->
    "[object #{@count}]"

Opcode.register 'lexical', class LexicalOpcode extends Opcode
  constructor: (@name) ->
  run: (frame) ->
    val = frame.getLexical @
    frame.push val
    frame.incIP()
  equals: (op) ->
    op instanceof LexicalOpcode and @name == op.name
  toString: () ->
    "[lexical #{@name}]"

Opcode.register 'ref', class ReferenceOpcode extends Opcode
  constructor: (@name) ->
  run: (frame) ->
    val = frame.ref @name
    frame.push val
    frame.incIP()
  equals: (op) ->
    op instanceof ReferenceOpcode and @name == op.name
  toString: () ->
    "[ref #{@name}]"

Opcode.register 'member', class MemberOpcode extends Opcode
  constructor: (@key) ->
  run: (frame) ->
    obj = frame.pop()
    val = obj[@key]
    if typeof(val) == 'function' or val instanceof Function
      # this will require more work... because we have to deal with its results...
      proc = (args...) ->
        val.call obj, args...
      frame.push proc
    else
      frame.push val
    frame.incIP()
  equals: (op) ->
    op instancoef MemberOpcode and @key == op.key
  toString: () ->
    "[member #{@key}]"

Opcode.register 'define', class DefineOpcode extends Opcode
  constructor: (@name) ->
  run: (frame) ->
    val = frame.pop()
    frame.env.define @name, val
    frame.push val
    frame.incIP()
  equals: (op) ->
    op instanceof DefineOpcode and @name == op.name
  toString: () ->
    "[define #{@name}]"

Opcode.register 'set', class SetOpcode extends Opcode
  constructor: (@name) ->
  run: (frame) ->
    val = frame.pop()
    frame.env.set @name, val
    frame.incIP()
  equals: (op) ->
    op instanceof SetOpcode and @name == op.name
  toString: () ->
    "[set #{@name}]"

Opcode.registerSingleton 'pushEnv', class PushEnvOpcode extends Opcode
  run: (frame) ->
    frame.pushEnv()
    frame.incIP()
  toString: () ->
    '[pushEnv]'

Opcode.registerSingleton 'popEnv', class PushEnvOpcode extends Opcode
  run: (frame) ->
    frame.popEnv()
    frame.incIP()
  toString: () ->
    '[popEnv]'

Opcode.register 'let', class LetOpcode extends Opcode
  constructor: (@name) ->
  run: (frame) ->
    val = frame.pop()
    frame.setLexical @name, val
    frame.incIP()
  equals: (op) ->
    op instanceof LetOpcode and @name == op.name
  toString: () ->
    "[let #{@name}]"

Opcode.registerSingleton 'throw', class ThrowOpcode extends Opcode
  run: (frame) ->
    err = frame.pop()
    frame.throw err
  toString: () ->
    "[throw]"

Opcode.register 'label', class LabelOpcode extends Opcode
  @id: 1
  constructor: (@name) ->
    @id = @constructor.id++
    @label = "__#{@name}_#{@id}"
  toString: () ->
    "[label #{@name}]"

Opcode.register 'goto', class GotoOpcode extends Opcode
  constructor: (@label) ->
  run: (frame) ->
    frame.goto @label
  toString: () ->
    "[goto #{@label}]"

Opcode.registerSingleton 'finally', class FinallyOpcode extends Opcode
  run: (frame) ->
    val = frame.pop()
    frame.finally = val
    frame.incIP()
  toString: () ->
    "[finally]"

Opcode.registerSingleton 'endFinally', class EndFinallyOpcode extends Opcode
  run: (frame) ->
    frame.push frame.finally
    frame.incIP()
  toString: () ->
    "[/finally]"

Opcode.register 'ifErrorOrJump', class IfErrorOrJumpOpcode extends Opcode
  constructor: (@count) ->
  run: (frame) ->
    if frame.task.error
      frame.incIP()
    else
      frame.jump @count
  equals: (op) ->
    op instanceof IfErrorOrJumpOpcode and @count == op.count
  toString: () ->
    "[ifErrorOrJump #{@count}]"

Opcode.register 'bindErrorOrJump', class BindErrorOrJumpOpcode extends Opcode
  constructor: (@count) ->
  run: (frame) ->
    param = frame.pop()
    if param.isa frame.task.error
      frame.env.define param.name, frame.task.popError()
      frame.incIP()
    else
      frame.jump @count
  equals: (op) ->
    op instanceof BindErrorOrJumpOpcode and @count == op.count
  toString: () ->
    "[bindErrorOrJump #{@count}]"

Opcode.register 'onThrowGoto', class TryOnErrorGotoOpcode extends Opcode
  constructor: (@label) ->
  run: (frame) ->
    frame.pushThrowLabel @label
    frame.incIP()
  equals: (op) ->
    op instanceof TryOnErrorGotoOpcode and @label.equals(op.label)
  toString: () ->
    "[onThrowGoto #{@label}]"

Opcode.register 'ifOrJump', class IfOrJumpOpcode extends Opcode
  constructor: (@count = 1) ->
  run: (frame) ->
    val = frame.pop()
    if val 
      frame.incIP()
    else
      frame.jump @count
  equals: (op) ->
    op instanceof IfOrJumpOpcode and @count == op.count
  toString: () ->
    "[ifOrJump #{@count}]"

Opcode.registerSingleton 'else', class ElseOpcode extends Opcode
  run: (frame) ->
    @skipPassEnd frame
  skipPassEnd: (frame) ->
    while ((opcode = frame.current()) and not (opcode instanceof EndOpcode))
      frame.incIP()
    frame.incIP()
  toString: () ->
    '[else]'

Opcode.registerSingleton 'if', class IfOpcode extends Opcode
  run: (frame) ->
    cond = frame.pop()
    if cond
      frame.incIP()
    else
      @skipToElse frame
  skipToElse: (frame) ->
    while ((opcode = frame.current()) and not ((opcode instanceof ElseOpcode) or (opcode instanceof EndOpcode)))
      frame.incIP()
    frame.incIP()
  toString: () ->
    '[if]'

Opcode.register 'jump', class JumpOpcode extends Opcode
  constructor: (@count = 1) ->
  run: (frame) ->
    frame.jump @count
  equals: (op) ->
    op instanceof JumpOpcode and @count == op.count
  toString: () ->
    "[jump #{@count}]"

class BinaryOpcode extends Opcode
  constructor: () ->
    @op = @constructor.op
  run: (frame) ->
    try 
      [ a1, a2 ] = frame.popN(2)
      frame.push @exec(a1, a2)
      frame.incIP()
    catch e 
      frame.error e
  exec: (a1, a2) ->
  toString: () ->
    "[#{@op}]"

Opcode.registerSingleton '+', class PlusOpCode extends BinaryOpcode
  @op: '+'
  exec: (a1, a2) -> a1 + a2 

Opcode.registerSingleton '-', class MinusOpcode extends BinaryOpcode
  @op: '-'
  exec: (a1, a2) -> a1 - a2 

Opcode.registerSingleton '*', class MultiplyOpcode extends BinaryOpcode
  @op: '*'
  exec: (a1, a2) -> a1 * a2

Opcode.registerSingleton '/', class DevideOpcode extends BinaryOpcode
  @op: '/'
  exec: (a1, a2) -> a1 / a2

Opcode.registerSingleton '%', class ModuloOpcode extends BinaryOpcode
  @op: '%'
  exec: (a1, a2) -> a1 % a2

Opcode.registerSingleton '>', class GreaterOpcode extends BinaryOpcode
  @op: '>'
  exec: (a1, a2) -> a1 > a2

Opcode.registerSingleton '>=', class GreaterThanOpcode extends BinaryOpcode
  @op: '>='
  exec: (a1, a2) -> a1 >= a2

Opcode.registerSingleton '<', class LessOpcode extends BinaryOpcode
  @op: '<'
  exec: (a1, a2) -> a1 < a2

Opcode.registerSingleton '<=', class LessThanOpcode extends BinaryOpcode
  @op: '<='
  exec: (a1, a2) -> a1 <= a2

Opcode.registerSingleton '==', class EqualOpcode extends BinaryOpcode
  @op: '=='
  exec: (a1, a2) -> a1 == a2

Opcode.registerSingleton '!=', class NotEqualOpcode extends BinaryOpcode
  @op: '!='
  exec: (a1, a2) -> a1 != a2

module.exports = Opcode
