Opcode = require './opcode'
errorlet = require 'errorlet'
loglet = require 'loglet'

LabelOpcode = Opcode.get 'label'

class Labels
  constructor: () ->
    @labels = {}
    @positions = {} # these are the ordinal position of the 
  add: (label, index) ->
    @labels[label.label] = label
    @positions[label.label] = index
  findLabel: (label) ->
    if typeof(label) == 'string'
      if @positions.hasOwnProperty(label)
        @positions[label]
      else
        throw errorlet.create {error: 'unknown_label', label: label}
    else if label instanceof LabelOpcode
      @findLabel label.label
    else
      throw errorlet.create {error: 'unknown_label', label: label}

class CodeBlock 
  @make: (block) ->
    if block instanceof CodeBlock
      block
    else if block instanceof Array
      new @ block
    else
      throw errorlet.create {error: 'invalid_codeblock_format', block: block}
  constructor: (items = []) ->
    @length = 0
    @labels = new Labels()
    @items = []
    for opcode in items
      @_addOpcode opcode
  equals: (code) ->
    if not @items.length == code.items.length 
      return false
    for i in [0...@items.length]
      op1 = @items[i]
      op2 = code.items[i]
      if not op1.equals op2
        return false
    true
  findLabel: (label) ->
    @labels.findLabel label
  add: (key, args...) ->
    @_addOpcode Opcode.make key, args...
    @
  _addOpcode: (opcode) ->
    @items.push opcode
    if opcode instanceof LabelOpcode
      @labels.add opcode, @length
    @length += 1
    @
  append: (codeblock) ->
    for opcode in codeblock.items
      @_addOpcode opcode
    @
  push: (arg) ->
    @add 'push', arg
  popN: (count = 1) ->
    @add 'popN', count
  plus: () ->
    @add '+'
  minus: () ->
    @add '-'
  multiply: () ->
    @add '*'
  divide: () ->
    @add '/'
  modulo: () ->
    @add '%'
  greater: () ->
    @add '>'
  greaterEqual: ()->
    @add '>='
  less: () ->
    @add '<'
  lessEqual: () ->
    @add '<='
  equal: () ->
    @add '=='
  notEqual: () ->
    @add '!=' 
  block: () ->
    @add '{{'
  endBlock: () ->
    @add '}}'
  if: () ->
    @add 'if'
  else: () ->
    @add 'else'
  begin: () ->
    @add 'begin'
  end: () ->
    @add 'end'
  array: (count) ->
    @add 'array', count
  object: (count) ->
    @add 'object', count
  member: (key) ->
    @add 'member', key
  param: (type) ->
    @add 'param', type
  paramList: (count) ->
    @add 'paramList', count
  funcall: (func) ->
    @add 'funcall', func
  tailcall: (func) ->
    @add 'tailcall', func
  throw: () ->
    @add 'throw'
  onThrowGoto: (label) ->
    @add 'onThrowGoto', label
  finally: () ->
    @add 'finally'
  endFinally: () ->
    @add 'endFinally'
  ifErrorOrJump: (count) ->
    @add 'ifErrorOrJump', count
  bindErrorOrJump: (count) ->
    @add 'bindErrorOrJump', count
  pushEnv: () ->
    @add 'pushEnv'
  popEnv: () ->
    @add 'popEnv'
  procedure: () ->
    @add 'procedure'
  lexical: (id) ->
    @add 'lexical', id
  apply: (count) ->
    @add 'apply', count
  ref: (name) ->
    @add 'ref', name
  define: (name) ->
    @add 'define', name
  set: (name) ->
    @add 'set', name
  ifOrJump: (count) ->
    @add 'ifOrJump', count
  jump: (count) ->
    @add 'jump', count
  label: (name) ->
    label = 
      if name instanceof LabelOpcode
        name
      else
        Opcode.make 'label', name
    @_addOpcode label
    @

Opcode.registerSingleton '}}', class EndBlockOpcode extends Opcode
  toString: () ->
    '[/block]'

Opcode.registerSingleton '{{', class BlockOpcode extends Opcode
  run: (frame) ->
    list = []
    frame.incIP()
    ip = frame.ip
    done = false
    while ((opcode = frame.current()) and not (opcode instanceof EndBlockOpcode))
      list.push opcode
      frame.incIP()
    frame.push new CodeBlock(list)
    frame.incIP()
  toString: () ->
    '[block]'

module.exports = CodeBlock