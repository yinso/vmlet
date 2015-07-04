loglet = require 'loglet'
errorlet = require 'errorlet'
esnode = require './esnode'
TR = require './trace'

_hashCode = (str) ->
  val = 0
  for i in [0...str.length]
    char = str.charCodeAt i 
    val = ((val<<5) - val) + char
    val = val & val
  val

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
  hashCode: () ->
    _hashCode @toString()
  inspect: () ->
    @toString()
  toString: () ->
    "{#{@constructor.name} #{@value}}"
  toESNode: () ->
    {type: 'Node'}
  canReduce: () ->
    false
  baseSelfESNode: (args...) ->
    esnode.funcall(esnode.member(esnode.member(esnode.identifier('_rt'), esnode.identifier('AST')), esnode.identifier(@constructor.type)), args)
  selfESNode: () ->
    @baseSelfESNode (if @value instanceof AST then @value.selfESNode() else esnode.literal(@value))

AST.register class SYMBOL extends AST
  @type: 'symbol'
  constructor: (@value, @suffix = undefined) ->
  _equals: (v) ->
    @value == v.value and @suffix == v.suffix
  nested: () ->
    new @ @value, if @suffix == undefined then 1 else @suffix + 1 
  toString: () ->
    if @suffix
      "{SYM #{@value};#{@suffix}}"
    else
      "{SYM #{@value}}"
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
  selfESNode: () -> 
    @baseSelfESNode()

AST.register class NUMBER extends AST
  @type: 'number'
  toESNode: () ->
    if @value < 0 
      esnode.unary '-', esnode.literal -@value
    else
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
  selfESNode: () ->
    @baseSelfESNode @head.selfESNode(), @key.selfESNode()

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
  selfESNode: () ->
    @baseSelfESNode esnode.array(esnode.array(esnode.literal(key), val.selfESNode()) for [key, val] in @value)

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
  selfESNode: () ->
    @baseSelfESNode esnode.array(item.selfESNode() for item in @value)

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
  selfESNode: () ->
    @baseSelfESNode esnode.array(item.selfESNode() for item in @items)

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
    esnode.assign @name.toESNode(), @value.toESNode() 
  canReduce: () -> true # this is actually not necessarily true...!!!
  selfESNode: () ->
    @baseSelfESNode @name.selfESNode(), @value.selfESNode()

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
    esnode.declare 'var', [ @name.toESNode(), @value.toESNode() ]
  canReduce: () -> true # this is actually not necessarily true...!!!
  selfESNode: () ->
    @baseSelfESNode @name.selfESNode(), @value.selfESNode()

AST.register class LOCAL extends AST 
  @type: 'local'
  constructor: (@name, @value) ->
  _equals: (v) ->
    @name == v.name and @value.equals(v.value)
  isAsync: () ->
    @value?.isAsync() or false
  toString: () ->
    "{LOCAL #{@name} #{@value}}"
  toESNode: () ->
    if not @value
      esnode.declare 'var', [ @name.toESNode() ]
    else
      esnode.declare 'var', [ @name.toESNode() , @value.toESNode() ]
  noInit: () ->
    AST.local @name
  assign: (value = @value) ->
    AST.assign @name, value
  canReduce: () -> true # this is actually not necessarily true...!!!
  selfESNode: () ->
    if @value
      @baseSelfESNode @name.selfESNode() , @value.selfESNode()
    else
      @baseSelfESNode @name.selfESNode()

# REF is used to determine whether or not we are referring to exactly the same thing.
AST.register class REF extends AST 
  @type: 'ref'
  constructor: (@name, @value) ->
    
  _equals: (v) -> @ == v
  isAsync: () -> false
  toString: () ->
    "{REF #{@name} #{@value}}"
  local: () ->
    AST.local @, @value
  define: () ->
    AST.define @, @value
  assign: () ->
    AST.assign @, @value
  toESNode: () ->
    @name.toESNode()
  selfESNode: () ->
    @baseSelfESNode @name.toESNode(), @value.toESNode()

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
    esnode.declare 'var', [ esnode.identifier(@normalized()), @value.toESNode() ]
  selfESNode: () ->
    @baseSelfESNode esnode.literal(@name), @value.selfESNode(), esnode.literal(@suffix)

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
    esnode.declare 'var', [ esnode.identifier(@name), @value.toESNode() ]
  selfESNode: () ->
    @baseSelfESNode esnode.literal(@name), @value.selfESNode(), esnode.literal(@_compile)

AST.register class PARAM extends AST
  constructor: (@name, @paramType = null, @default = null) ->
  @type: 'param'
  _equals: (v) ->
    @_typeEquals(v) and @_defaultEquals(v)
  _typeEquals: (v) ->
    if @paramType and v.paramType
      @paramType.equals(v.paramType)
    else if @paramType == null and v.paramType == null
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
    if @paramType and @default
      "{PARAM #{@name} #{@paramType} = #{@default}}"
    else if @paramType 
      "{PARAM #{@name} #{@paramType}}"
    else if @default
      "{PARAM #{@name} = #{@default}}"
    else 
      "{PARAM #{@name}}"
  toESNode: () ->
    @name.toESNode()
  selfESNode: () ->
    type = @paramType?.selfESNode() or esnode.literal @paramType
    defaultVal = @default?.selfESNode() or esnode.literal(@default)
    name = @name.selfESNode()
    @baseSelfESNode name, type, defaultVal

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
    func = esnode.function @name?.toESNode() or null, (param.toESNode() for param in @params), @body.toESNode()
    maker = esnode.member(esnode.identifier('_rt'), esnode.identifier('makeProc'))
    #esnode.funcall maker, [ func , @selfESNode() ]
    esnode.funcall maker, [ func ]
  selfESNode: () ->
    params = 
      esnode.array(param.selfESNode() for param in @params )
    name = if @name then esnode.literal(@name) else esnode.null_()
    @baseSelfESNode name, params, @body.selfESNode(), @returns?.selfESNode() or esnode.literal(@returns)

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
    esnode.function @name?.toESNode() or null, (param.toESNode() for param in @params), @body.toESNode()
  selfESNode: () ->
    params = 
      esnode.array(param.selfESNode() for param in @params )
    name = if @name then esnode.identifier(@name) else esnode.null_()
    @baseSelfESNode name, params, @body.selfESNode(), @returns?.selfESNode() or esnode.literal(@returns)

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
  selfESNode: () ->
    @baseSelfESNode @cond.selfESNode(), @then.selfESNode(), @else.selfESNode()

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
  selfESNode: () ->
    @baseSelfESNode @funcall.selfESNode(), esnode.array(arg.selfESNode() for arg in @args)

AST.register class TASKCALL extends FUNCALL
  @type: 'taskcall'
  isAsync: () ->
    true
  toString: () ->
    "{TASKCALL #{@funcall} #{@args}}"
  toESNode: () ->
    esnode.funcall @funcall.toESNode(), (arg.toESNode() for arg in @args)
  selfESNode: () ->
    @baseSelfESNode @funcall.selfESNode(), esnode.array(arg.selfESNode() for arg in @args)

AST.register class RETURN extends AST
  @type: 'return'
  isAsync: () ->
    @value.isAsync()
  toESNode: () ->
    esnode.return @value.toESNode()
  canReduce: () ->
    @value.canReduce()
  selfESNode: () -> 
    @baseSelfESNode @value.selfESNode()

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
  selfESNode: () ->
    @baseSelfESNode esnode.literal(@op), @lhs.selfESNode(), @rhs.selfESNode()

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
  selfESNode: () ->
    @baseSelfESNode @param.selfESNode(), @body.selfESNode()

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
  selfESNode: () ->
    @baseSelfESNode @body.selfESNode()

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
          return true
      @finally?.isAsync() or false 
  toString: () ->
    "{TRY #{@body} #{@catches} #{@finally}}"
  toESNode: () ->
    esnode.try @body.toESNode(), (exp.toESNode() for exp in @catches), @finally?.toESNode() or null
  canReduce: () -> true
  selfESNode: () ->
    catches = esnode.array(exp.selfESNode() for exp in @catches)
    final = @finally?.selfESNode() or esnode.literal(@finally)
    @baseSelfESNode @body.selfESNode(), catches, final

###

WHILE, CONTINUE, SWITCH, CASE, and DEFAULT

These are used for tail call transformations.

###

AST.register class VAR extends AST 
  @type: 'var'
  constructor: (@name) ->
  toString: () -> 
    "{VAR #{@name}}"
  toESNode: () ->
    esnode.declare 'var', [ esnode.identifier(@name), null ]
  selfESNode: () -> 
    @baseSelfESNode esnode.literal(@name)

AST.register class WHILE extends AST
  @type: 'while'
  constructor: (@cond, @block) ->
  _equals: (v) ->
    @cond.equals(v.cond) and @block.equals(v.block)
  isAsync: () ->
    @cond.isAsync() or @block.isAsync()
  toString: () ->
    "{WHILE #{@cond} #{@block}}"
  toESNode: () ->
    escode.while @cond.toESNode(), @block.toESNode()
  selfESNode: () -> 
    @baseSelfESNode @cond.selfESNode(), @block.selfESNode()

AST.register class CONTINUE extends AST
  @type: 'continue'
  toString: () -> 
    "{CONTINUE}"
  toESNode: () ->
    escode.continue()
  selfESNode: () -> 
    @baseSelfESNode()

AST.register class SWITCH extends AST
  @type: 'switch'
  constructor: (@cond, @cases = []) ->
  toString: () ->
    "{SWITCH #{@cond} #{@cases}}"
  toESNode: () ->
    escode.switch @cond.toESNode(), (c.toESNode() for c in @cases)
  selfESNode: () ->
    @baseSelfESNode @cond.selfESNode(), (c.selfESNode() for c in @cases)

AST.register class CASE extends AST
  @type: 'case'
  constructor: (@cond, @exp) ->
  toString: () ->
    "{CASE #{@cond} #{@exp}}"
  toESNode: () ->
    escode.case @cond.toESNode(), @exp.toESNode()
  selfESNode: () ->
    @baseSelfESNode @cond.selfESNode(), @exp.selfESNode()
  

AST.register class DEFAULTCASE extends AST
  @type: 'defaultCase'
  constructor: (@exp) ->
  toString: () ->
    "{DEFAULT #{@exp}}"
  toESNode: () ->
    escode.defaultCase @exp.toESNode()
  selfESNode: () ->
    @baseSelfESNode @exp.selfESNode()


module.exports = AST
