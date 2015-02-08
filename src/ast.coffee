loglet = require 'loglet'
errorlet = require 'errorlet'

class AST
  @types: {}
  @register: (astType) ->
    if @types.hasOwnProperty(astType.type)
      throw errorlet.create {error: 'ast_type:duplicate', type: astType.type, ast: ast}
    @types[astType.type] = astType
  @get: (type) ->
    if @types.hasOwnProperty(type)
      @types[type]
    else
      throw errorlet.create {error: 'ast_type:unknown', type: type}
  @make: (type, args...) ->
    astType = @get type
    new astType args...
  @isa: (v, type) -> v instanceof @get(type)
  constructor: (@val) ->
  equals: (v) -> 
    v instanceof @constructor and @_equals(v)
  _equals: (v) -> v.val == @val
  isa: (v, type) ->
    v instanceof AST.get(type)
  type: () ->
    @constructor.type
  inspect: () ->
    @toString()
  toString: () ->
    "{#{@constructor.name} #{@val}}"
  
AST.register class SYMBOL extends AST
  @type: 'symbol'

AST.register class STRING extends AST
  @type: 'string'
    
AST.register class BOOL extends AST
  @type: 'bool'
  @TRUE = new BOOL(true)
  @FALSE = new BOOL(false)

AST.register class NULL extends AST
  @type: 'null'
  @NULL = new NULL(true)

AST.register class NUMBER extends AST
  @type: 'number'

AST.register class MEMBER extends AST
  constructor: (@head, @key) ->
  @type: 'member'
  _equals: (v) -> 
    @head.equals(v.head) and @key == v.key
  toString: () ->
    "{MEMBER #{@head} #{@key}}"

AST.register class OBJECT extends AST
  @type: 'object'
  _equals: (v) -> 
    if not @val.length == v.val.length
      return false
    for i in [0...@val.length]
      o1 = @val[i]
      o2 = v.val[i]
      if not o1.equals(o2)
        return false
    true

AST.register class ARRAY extends AST
  @type: 'array'
  _equals: (v) ->
    if not @val.length == v.val.length
      return false
    for i in [0...@val.length]
      a1 = @val[i]
      a2 = v.val[i]
      if not a1.equals(a2)
        return false
    true

AST.register class LIST extends AST
  @type: 'list'
  _equals: (v) -> 
    if v.val == @val.length
      for val, i in v.val
          res = @val[i].equals(val)
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
    @val.equals(v.val)

AST.register class QUASI extends AST
  @type: 'quasi'
  _equals: (v) ->
    @val.equals(v.val)

AST.register class UNQUOTE extends AST
  @type: 'unquote'
  _equals: (v) ->
    @val.equals(v.val)

AST.register class UNQUOTESPLICING extends AST
  @type: 'unquotesplicing'
  _equals: (v) ->
    @val.equals(v.val)

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
  toString: () ->
    buffer = []
    buffer.push '{BLOCK'
    for item in @items
      buffer.push item
    buffer.push '}'
    buffer.join '\n'

AST.register class REF extends AST
  @type: 'ref'

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
    "{PROCEDURE #{@name} #{@params} #{@body} #{@returns}}"

AST.register class IF extends AST
  @type: 'if'
  constructor: (@if, @then, @else) ->
  _equals: (v) ->
    @if.equals(v.if) and @then.equals(v.then) and @else.equals(v.else)
  toString: () ->
    "{IF #{@if} #{@then} #{@else}}"

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

AST.register class DEFINE extends AST
  @type: 'define'
  constructor: (@name, @val) ->
  _equals: (v) ->
    @name == v.name and @val.equals(v.val)
  toString: () ->
    "{DEFINE #{@name} #{@val}}"

AST.register class TEMPVAR extends AST
  @type: 'tempvar'
  constructor: (@name, @val) ->
  _equals: (v) ->
    @name == v.name and @val.equals(v.val)
  toString: () ->
    "{TEMPVAR #{@name} #{@val}}"
  

AST.register class RETURN extends AST
  @type: 'return'

AST.register class BINARY extends AST
  @type: 'binary'
  constructor: (@op, @lhs, @rhs) ->
  _equals: (v) ->
    @op == v.op and @lhs.equals(v.lhs) and @rhs.equals(v.rhs)
  toString: () ->
    "{#{@op} #{@lhs} #{@rhs}}"

AST.register class THROW extends AST
  @type: 'throw'

AST.register class CATCH extends AST
  @type: 'catch'
  constructor: (@param, @body) ->
  _equals: (v) ->
    @param.equals(v.param) and @body.equals(v.body)
  toString: () ->
    "{CATCH #{@param} #{@body}}"

AST.register class FINALLY extends AST
  @type: 'finally'
  constructor: (@body) ->
  _equals: (v) ->
    @body.equals(v.body)
  toString: () ->
    "{FINALLY #{@body}}"

AST.register class TRY extends AST 
  @type: 'try'
  constructor: (@body, @catch = [], @finally = null) ->
  _equals: (v) ->
    if not @body.equals(v.body)
      return false
    if not @catch.length == v.catch.length
      return false
    for i in [0...@catch.length]
      c1 = @catch[i]
      c2 = v.catch[i]
      if not c1.equals(c2)
        return false
    if @finally and v.finally
      @finally.equals(v.finally)
    else if not @finally and not v.finally
      true
    else
      false
  toString: () ->
    "{TRY #{@body} #{@catch} #{@finally}}"

module.exports = AST
