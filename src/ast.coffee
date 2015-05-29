loglet = require 'loglet'
errorlet = require 'errorlet'
esnode = require './esnode'

class AST
  @types: {}
  @register: (astType) ->
    if @types.hasOwnProperty(astType.type)
      throw errorlet.create {error: 'ast_type:duplicate', type: astType.type, ast: ast}
    @types[astType.type] = astType
    @[astType.type] = (args...) ->
      new astType args...
  @get: (type) ->
    if @types.hasOwnProperty(type)
      @types[type]
    else
      throw errorlet.create {error: 'ast_type:unknown', type: type}
  @make: (type, args...) ->
    astType = @get type
    new astType args...
  @isa: (v, type) -> v instanceof @get(type)
  constructor: (@value) ->
  equals: (v) -> 
    v instanceof @constructor and @_equals(v)
  _equals: (v) -> v.value == @value
  isa: (type) ->
    @ instanceof AST.get(type)
  isAsync: () -> false
  type: () ->
    @constructor.type
  inspect: () ->
    @toString()
  toString: () ->
    "{#{@constructor.name} #{@value}}"
  toESNode: () ->
    {type: 'Node'}
  canReduce: () ->
    false

AST.register class SYMBOL extends AST
  @type: 'symbol'
  toESNode: () ->
    esnode.identifier @value

AST.register class STRING extends AST
  @type: 'string'
  toESNode: () ->
    esnode.literal @value
    
AST.register class BOOL extends AST
  @type: 'bool'
  @TRUE = new BOOL(true)
  @FALSE = new BOOL(false)
  toESNode: () ->
    esnode.literal @value

AST.register class NULL extends AST
  @type: 'null'
  @NULL = new NULL(true)
  toString: () ->
    "{NULL}"
  toESNode: () ->
    esnode.null_()

AST.register class NUMBER extends AST
  @type: 'number'
  toESNode: () ->
    esnode.literal @value

AST.register class MEMBER extends AST
  constructor: (@head, @key) ->
  @type: 'member'
  _equals: (v) -> 
    @head.equals(v.head) and @key == v.key
  toString: () ->
    "{MEMBER #{@head} #{@key}}"
  toESNode: () ->
    esnode.member @head.toESNode(), @key.toESNode()
  canReduce: () ->
    @head.canReduce()

AST.register class UNIT extends AST
  @type: 'unit'
  constructor: () ->
  _equals: (v) -> true
  toString: () ->
    "{UNIT}"
  toESNode: () ->
    esnode.undefined_()

AST.register class OBJECT extends AST
  @type: 'object'
  _equals: (v) -> 
    if not @value.length == v.value.length
      return false
    for i in [0...@value.length]
      o1 = @value[i]
      o2 = v.value[i]
      if not o1.equals(o2)
        return false
    true
  toESNode: () ->
    esnode.object ([key, val.toESNode()] for [key, val] in @value)
  canReduce: () ->
    for [ key, val ] in @value
      if val.canReduce()
        return true
    return false

AST.register class ARRAY extends AST
  @type: 'array'
  _equals: (v) ->
    if not @value.length == v.value.length
      return false
    for i in [0...@value.length]
      a1 = @value[i]
      a2 = v.value[i]
      if not a1.equals(a2)
        return false
    true
  toESNode: () ->
    esnode.array (item.toESNode() for item in @value)
  canReduce: () ->
    for val in @value
      if val.canReduce()
        return true
    return false

AST.register class LIST extends AST
  @type: 'list'
  _equals: (v) -> 
    if v.value == @value.length
      for val, i in v.value
          res = @value[i].equals(val)
          if res
            continue
          else
            return false
      true
    else
      false  

AST.register class QUOTED extends AST
  @type: 'quoted'
  _equals: (v) ->
    @value.equals(v.value)

AST.register class QUASI extends AST
  @type: 'quasi'
  _equals: (v) ->
    @value.equals(v.value)

AST.register class UNQUOTE extends AST
  @type: 'unquote'
  _equals: (v) ->
    @value.equals(v.value)

AST.register class UNQUOTESPLICING extends AST
  @type: 'unquotesplicing'
  _equals: (v) ->
    @value.equals(v.value)

AST.register class BLOCK extends AST
  constructor: (@items = []) ->
  @type: 'block'
  _equals: (v) -> 
    if v.items.length == @items.length
      for val, i in v.items
          res = @items[i].equals(val)
          if res
            continue
          else
            return false
      true
    else
      false 
  isAsync: () ->
    for item in @items
      if item.isAsync()
        true
    false
  toString: () ->
    buffer = []
    buffer.push '{BLOCK'
    for item in @items
      buffer.push item.toString()
    buffer.push '}'
    buffer.join '\n'
  push: (item) ->
    @items.push item # this line causes range error???
    item
  toESNode: () ->
    esnode.block (item.toESNode() for item in @items)
  canReduce: () -> true # this is actually not necessarily true...!!!

#AST.register class TOPLEVEL extends BLOCK
#  @type: 'toplevel'

AST.register class REF extends AST
  @type: 'ref'
  constructor: (@name, @value, @suffix = 0) ->
  normalized: () ->
    @name + if @suffix > 0 then "$#{@suffix}" else ''
  isAsync: () ->
    @value.isAsync()
  toString: () ->
    "{REF #{@normalized()}}"
  local: (init = true) ->
    AST.local @, init
  define: () ->
    AST.define @name, @value
  toESNode: () ->
    esnode.identifier @normalized()

AST.register class ASSIGN extends AST
  @type: 'assign'
  constructor: (@name, @value) ->
  _equals: (v) ->
    @name == v.name and @value.equals(v.value)
  isAsync: () ->
    @value.isAsync()
  toString: () ->
    "{ASSIGN #{@name} #{@value}}"
  toESNode: () ->
    esnode.assign @name, @value 
  canReduce: () -> true # this is actually not necessarily true...!!!

AST.register class DEFINE extends AST
  @type: 'define'
  constructor: (@name, @value) ->
  _equals: (v) ->
    @name == v.name and @value.equals(v.value)
  isAsync: () ->
    @value.isAsync()
  toString: () ->
    "{DEFINE #{@name} #{@value}}"
  toESNode: () ->
    esnode.declare 'var', [ @name, @value.toESNode() ]
  canReduce: () -> true # this is actually not necessarily true...!!!

AST.register class LOCAL extends AST
  @type: 'local'
  constructor: (@value, @init = true) ->
    if not (@value instanceof REF)
      throw new Error("LOCAL:not_a_REF #{@value}")
  isAsync: () ->
    @value.isAsync()
  clone: (val, init = true) ->
    ref = AST.ref @value.name, val, @value.suffix
    ref.local(init)
  noInit: () -> 
    @clone @normalized(), false
  name: () ->
    @value.normalized()
  normalized: () ->
    @value.value
  assign: (value = @normalized()) ->
    AST.assign @name(), value
  toString: () ->
    if @init
      "{LOCAL #{@name()} = #{@normalized()}}"
    else
      "{LOCAL #{@name()}}"
  toESNode: () ->
    if @init 
      esnode.declare 'var', [ @name(), @value.toESNode() ]
    else
      esnode.declare 'var', [ @name(), null ]
  canReduce: () -> true # this is actually not necessarily true...!!!

# temp var should really just be a way to coin a particular reference - the reference itself should have 
# automatic names...

AST.register class TEMPVAR extends AST
  @type: 'tempvar'
  constructor: (@name, @value, @suffix = '') ->
  _equals: (v) ->
    @name == v.name and @value.equals(v.value)
  isAsync: () ->
    @value.isAsync()
  normalized: () ->
    @name + if @suffix then "$#{@suffix}" else ''
  toString: () ->
    "{TEMPVAR #{@normalized()} #{@value}}"
  toESNode: () ->
    esnode.declare 'var', [ @normalized(), @value.toESNode() ]

# PROXYVAL - used to hold the actual value of the 

AST.register class PROXYVAL extends AST
  @type: 'proxyval'
  constructor: (@name, @value, @_compile = null) ->
  # compile is used by compiler to generate the final text.
  compile: () ->
    if @_compile
      @_compile(@)
    else
      @name # returning the name is the default.
  _equals: (v) ->
    @name == v.name and @value.equals(v.value)
  toString: () ->
    "{PROXYVAL #{@name} #{@value}}"
  toESNode: () ->
    esnode.declare 'var', [ @name, @value.toESNode() ]

AST.register class PARAM extends AST
  constructor: (@name, @type = null, @default = null) ->
  @type: 'param'
  _equals: (v) ->
    @_typeEquals(v) and @_defaultEquals(v)
  _typeEquals: (v) ->
    if @type and v.type
      @type.equals(v.type)
    else if @type == null and v.type == null
      true
    else
      false
  _defaultEquals: (v) ->
    if @default and v.default
      @default.equals(v.default)
    else if @default == null and v.default == null
      true
    else
      false
  toString: () ->
    "{PARAM #{@name} #{@type} #{@default}}"
  ref: () ->
    AST.ref @name, @
  toESNode: () ->
    esnode.identifier @name

AST.register class PROCEDURE extends AST
  @type: 'procedure'
  constructor: (@name, @params, @body, @returns = null) ->
  _equals: (v) ->
    if @name == @name
      for param, i in @params
        if not param.equals(v.params[i])
          return false
      @body.equals(v.body)
    else
      false
  toString: () ->
    buffer = ["{PROCEDURE "]
    if @name 
      buffer.push @name, " "
    buffer.push "("
    for param, i in @params or []
      if i > 0 
        buffer.push ", "
      buffer.push param.toString()
    buffer.push ") "
    buffer.push @body.toString()
    if @returns
      @buffer.push " : ", @returns.toString()
    buffer.push "}"
    buffer.join ''
  toESNode: () ->
    esnode.function @name, (param.toESNode() for param in @params), @body.toESNode()

AST.register class TASK extends AST
  @type: 'task'
  constructor: (@name, @params, @body, @returns = null) ->
  _equals: (v) ->
    if @name == @name
      for param, i in @params
        if not param.equals(v.params[i])
          return false
      @body.equals(v.body)
    else
      false
  isAsync: () ->
    @body.isAsync()
  toString: () ->
    "{TASK #{@name} #{@params} #{@body} #{@returns}}"
  toESNode: () ->
    esnode.function @name, (param.toESNode() for param in @params), @body.toESNode()

AST.register class IF extends AST
  @type: 'if'
  constructor: (@cond, @then, @else) ->
  _equals: (v) ->
    @cond.equals(v.cond) and @then.equals(v.then) and @else.equals(v.else)
  isAsync: () ->
    @then.isAsync() or @else.isAsync()
  toString: () ->
    "{IF #{@cond} #{@then} #{@else}}"
  toESNode: () ->
    esnode.if @cond.toESNode(), @then.toESNode(), @else.toESNode()
  canReduce: () -> true # this is actually not necessarily true...!!!

# this is meant for transformation rather than input...
AST.register class WHILE extends AST
  @type: 'while'
  constructor: (@cond, @block) ->
  _equals: (v) ->
    @cond.equals(v.cond) and @block.equals(v.block)
  isAsync: () ->
    @cond.isAsync() or @block.isAsync()
  toString: () ->
    "{WHILE #{@cond} #{@block}}"

AST.register class FUNCALL extends AST
  @type: 'funcall'
  constructor: (@funcall, @args) ->
  _equals: (v) ->
    if @funcall.equals(v.funcall)
      if @args.length == v.args.length
        for arg, i in @args
          if arg.equals(v.args[i])
            continue
          else
            return false
        return true
      else
        false
    else
      false
  toString: () ->
    "{FUNCALL #{@funcall} #{@args}}"
  toESNode: () ->
    esnode.funcall @funcall.toESNode(), (arg.toESNode() for arg in @args)
  canReduce: () -> # this is actually not necessarily true...!!!
    if @funcall.canReduce()
      return true
    for arg in @args 
      if arg.canReduce()
        return true
    return false

AST.register class TASKCALL extends FUNCALL
  @type: 'taskcall'
  isAsync: () ->
    true
  toString: () ->
    "{TASKCALL #{@funcall} #{@args}}"
  toESNode: () ->
    esnode.funcall @funcall.toESNode(), (arg.toESNode() for arg in @args)

AST.register class RETURN extends AST
  @type: 'return'
  isAsync: () ->
    @value.isAsync()
  toESNode: () ->
    esnode.return @value.toESNode()
  canReduce: () ->
    @value.canReduce()

AST.register class BINARY extends AST
  @type: 'binary'
  constructor: (@op, @lhs, @rhs) ->
  _equals: (v) ->
    @op == v.op and @lhs.equals(v.lhs) and @rhs.equals(v.rhs)
  toString: () ->
    "{#{@op} #{@lhs} #{@rhs}}"
  toESNode: () ->
    esnode.binary @op, @lhs.toESNode(), @rhs.toESNode()
  canReduce: () ->
    @lhs.canReduce() or @rhs.canReduce()

AST.register class THROW extends AST
  @type: 'throw'
  toESNode: () ->
    esnode.throw @value.toESNode()
  canReduce: () ->
    @value.canReduce()

AST.register class CATCH extends AST
  @type: 'catch'
  constructor: (@param, @body) ->
  _equals: (v) ->
    @param.equals(v.param) and @body.equals(v.body)
  isAsync: () ->
    @body.isAsync()
  toString: () ->
    "{CATCH #{@param} #{@body}}"
  toESNode: () ->
    esnode.catch @param.toESNode(), @body.toESNode()
  canReduce: () -> true

AST.register class FINALLY extends AST
  @type: 'finally'
  constructor: (@body) ->
  _equals: (v) ->
    @body.equals(v.body)
  isAsync: () ->
    @body.isAsync()
  toString: () ->
    "{FINALLY #{@body}}"
  toESNode: () ->
    @body.toESNode()
  canReduce: () -> 
    @body.canReduce()

AST.register class TRY extends AST 
  @type: 'try'
  constructor: (@body, @catches = [], @finally = null) ->
  _equals: (v) ->
    if not @body.equals(v.body)
      return false
    if not @catches.length == v.catches.length
      return false
    for i in [0...@catches.length]
      c1 = @catches[i]
      c2 = v.catches[i]
      if not c1.equals(c2)
        return false
    if @finally and v.finally
      @finally.equals(v.finally)
    else if not @finally and not v.finally
      true
    else
      false
  isAsync: () ->
    if @body.isAsync() 
      true
    else 
      for c in @catches
        if c.isAsync()
          true
      @finally.isAsync()
  toString: () ->
    "{TRY #{@body} #{@catches} #{@finally}}"
  toESNode: () ->
    escode.try @body.toESNode(), (exp.toESNode() for exp in @catches), @finally?.toESNode() or null
  canReduce: () -> true

module.exports = AST
