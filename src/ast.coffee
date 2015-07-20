loglet = require 'loglet'
errorlet = require 'errorlet'
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
  canReduce: () ->
    false

AST.register class SYMBOL extends AST
  @type: 'symbol'
  constructor: (@value, @suffix = undefined) ->
  _equals: (v) ->
    @value == v.value and @suffix == v.suffix
  nested: () ->
    new @constructor @value, if @suffix == undefined then 1 else @suffix + 1 
  clone: () ->
    new @constructor @value, if @suffix == undefined then 1 else @suffix + 1 
  toString: () ->
    if @suffix
      "{SYM #{@value};#{@suffix}}"
    else
      "{SYM #{@value}}"

runtimeID = AST.runtimeID = AST.symbol('_rt')
moduleID = AST.moduleID = AST.symbol('_module')

AST.register class STRING extends AST
  @type: 'string'
  
AST.register class BOOL extends AST
  @type: 'bool'
  @TRUE = new BOOL(true)
  @FALSE = new BOOL(false)

AST.register class NULL extends AST
  @type: 'null'
  @NULL = new NULL(true)
  toString: () ->
    "{NULL}"

AST.register class NUMBER extends AST
  @type: 'number'

AST.register class MEMBER extends AST
  constructor: (@head, @key) ->
  @type: 'member'
  _equals: (v) -> 
    @head.equals(v.head) and @key == v.key
  toString: () ->
    "{MEMBER #{@head} #{@key}}"
  canReduce: () ->
    @head.canReduce()

AST.register class UNIT extends AST
  @type: 'unit'
  constructor: () ->
  _equals: (v) -> true
  toString: () ->
    "{UNIT}"

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
  canReduce: () ->
    for val in @value
      if val.canReduce()
        return true
    return false

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
  canReduce: () -> true # this is actually not necessarily true...!!!

AST.register class ASSIGN extends AST
  @type: 'assign'
  constructor: (@name, @value) ->
  _equals: (v) ->
    @name == v.name and @value.equals(v.value)
  isAsync: () ->
    @value.isAsync()
  toString: () ->
    "{ASSIGN #{@name} #{@value}}"
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
  canReduce: () -> true # this is actually not necessarily true...!!!

AST.register class LOCAL extends AST 
  @type: 'local'
  constructor: (@name, @value) ->
  _equals: (v) ->
    @name == v.name and @value.equals(v.value)
  isAsync: () ->
    @value?.isAsync() or false
  toString: () ->
    "{LOCAL #{@name} #{@value}}"
  noInit: () ->
    AST.local @name
  assign: (value = @value) ->
    AST.assign @name, value
  canReduce: () -> true # this is actually not necessarily true...!!!

# REF is used to determine whether or not we are referring to exactly the same thing.
AST.register class REF extends AST 
  @type: 'ref'
  constructor: (@name, @value) ->
    @isDefine = false
  _equals: (v) -> @ == v
  isAsync: () -> false
  isPlaceholder: () ->
    not @value
  toString: () ->
    if @isDefine
      "{REF !#{@name}}"
    else
      "{REF #{@name}}"
  define: () ->
    if @isDefine
      AST.define @, @value
    else
      AST.local @, @value
  clone: () ->
    AST.ref @name.clone(), @value
  assign: () ->
    AST.assign @, @value
  export: (@as = null ) ->
    AST.export [ AST.binding(@, @as) ]
  normalName: () ->
    @name

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

# PROXYVAL 
# used to hold special transformation logic. 
# it acts similar to references but are used for underlying transformations...
# This generally should only be used by the compiler.
AST.register class PROXYVAL extends AST 
  @type: 'proxyval'
  constructor: (@name, @compiler) ->

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
  ref: () -> 
    AST.ref @name , @
  toString: () ->
    if @paramType and @default
      "{PARAM #{@name} #{@paramType} = #{@default}}"
    else if @paramType 
      "{PARAM #{@name} #{@paramType}}"
    else if @default
      "{PARAM #{@name} = #{@default}}"
    else 
      "{PARAM #{@name}}"

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
    if @body 
      buffer.push @body.toString()
    if @returns
      @buffer.push " : ", @returns.toString()
    buffer.push "}"
    buffer.join ''

# having LET expression is basically the same as 
AST.register class LET extends AST 
  @type: 'let'
  constructor: (@defines, @body) ->
  _equals: (v) -> 
    @ == v
  toString: () -> 
    "{LET #{@defines} #{@body}}"

AST.register class TASK extends AST
  @type: 'task'
  constructor: (@name, @params, @body, @returns = null) ->
    @callbackParam = AST.param AST.symbol('cb')
    @errorParam = AST.param AST.symbol('e')
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


AST.register class IF extends AST
  @type: 'if'
  constructor: (@cond, @then, @else) ->
  _equals: (v) ->
    @cond.equals(v.cond) and @then.equals(v.then) and @else.equals(v.else)
  isAsync: () ->
    @then.isAsync() or @else.isAsync()
  toString: () ->
    "{IF #{@cond} #{@then} #{@else}}"
  canReduce: () -> true # this is actually not necessarily true...!!!

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

AST.register class RETURN extends AST
  @type: 'return'
  isAsync: () ->
    @value.isAsync()
  canReduce: () ->
    @value.canReduce()

AST.register class BINARY extends AST
  @type: 'binary'
  constructor: (@op, @lhs, @rhs) ->
  _equals: (v) ->
    @op == v.op and @lhs.equals(v.lhs) and @rhs.equals(v.rhs)
  toString: () ->
    "{#{@op} #{@lhs} #{@rhs}}"
  canReduce: () ->
    @lhs.canReduce() or @rhs.canReduce()

AST.register class THROW extends AST
  @type: 'throw'
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
          return true
      @finally?.isAsync() or false 
  toString: () ->
    "{TRY #{@body} #{@catches} #{@finally}}"
  canReduce: () -> true

AST.register class TOPLEVEL extends AST 
  @type: 'toplevel'
  constructor: (body = AST.unit()) ->
    @moduleParam = AST.param(moduleID)
    @callbackParam = AST.param(AST.symbol('_done'))
    @errorParam = AST.param AST.symbol('e')
    @body = @normalizeBody body
    @imports = @extractImports @body
  extractImports: (ast, results = []) ->
    # imports should be @ at the top level expressions...
    switch ast.type()
      when 'block'
        for item in ast.items 
          @extractImports item, results
        results
      when 'import'
        results.push ast
        results
      else
        results
  clone: (body = @body) ->
    toplevel = new @constructor()
    toplevel.body = body
    toplevel.moduleParam = @moduleParam
    toplevel.callbackParam = @callbackParam
    toplevel.errorParam = @errorParam
    toplevel.imports = @imports 
    toplevel
  importSpecs: () ->
    imp.importSpec() for imp in @imports
  normalizeBlock: (body) ->
    if body.items.length == 1 and body.items[0].type() == 'define'
      body.push AST.unit()
    body
  normalizeBody: (body) ->
    switch body.type()
      when 'block'
        @normalizeBlock body
      when 'define'
        @normalizeDefine body
      else
        @normalizeOther body
  normalizeDefine: (body) ->
    AST.block [ 
        body 
        AST.unit()
      ]
  normalizeOther: (body) ->
    AST.block [
        body 
      ]
  _equals: (v) ->
    @body.equals v.body 
  isAsync: () -> true 
  toString: () ->
    "{TOPLEVEL #{@body}}"

AST.register class MODULE extends TOPLEVEL
  @type: 'module'
  constructor: (@spec = AST.string('/'), body = AST.unit()) ->
    super body
    @id = @normalizeSpec @spec
  normalizeSpec: (spec) ->
    # spec is going to be a string...
    AST.param AST.symbol spec.value.replace /[\.\/\\]/g, '_' 
  normalizeBody: (body) ->
    body = super body
    switch body.type()
      when 'block'
        body.items.push @moduleParam.ref()
        body
      else
        AST.block [ body , @moduleParam.ref() ]
  clone: (body = @body) -> 
    module = super body
    module.spec = @spec
    module.id = @normalizeSpec @spec
    module
  toString: () ->
    "{MODULE #{@body}}"

AST.register class BINDING extends AST
  @type: 'binding'
  constructor: (@spec, @as = null) ->
    if not @as
      @as = @spec
  toString: () ->
    if @as 
      "{AS #{@spec} #{@as}}"
    else
      "{#{@spec}}"

AST.register class IMPORT extends AST
  @type: 'import'
  constructor: (@spec, @bindings = []) ->
    # the spec ought to have a way to be translated for mapping...!
    @idParam = @normalizeSpec @spec
  normalizeSpec: () ->
    # spec is going to be a string...
    AST.param AST.symbol @spec.value.replace(/[\.\/\\]/g, '_') 
  toString: () ->
    "{IMPORT #{@spec}} #{@bindings}"
  defines: () ->
    for binding in @bindings 
      @define binding
  define: (binding) ->
    AST.define binding.as, AST.funcall(AST.member(@idParam.ref(), AST.symbol('get')), [AST.string(binding.spec.value)])
  proxy: (binding) ->
    AST.proxyval binding.as, AST.funcall(AST.member(moduleID, AST.symbol('get')), [ AST.string(binding.as.value)])
  importSpec: () ->
    @spec.value

AST.register class EXPORT extends AST 
  @type: 'export'
  constructor: (@bindings = []) ->
  toString: () ->
    "{EXPORT #{@bindings}}"
  isAsync: () -> false

###

WHILE, CONTINUE, SWITCH, CASE, and DEFAULT

These are used for tail call transformations.

###

AST.register class VAR extends AST 
  @type: 'var'
  constructor: (@name) ->
  toString: () -> 
    "{VAR #{@name}}"

AST.register class WHILE extends AST
  @type: 'while'
  constructor: (@cond, @block) ->
  _equals: (v) ->
    @cond.equals(v.cond) and @block.equals(v.block)
  isAsync: () ->
    @cond.isAsync() or @block.isAsync()
  toString: () ->
    "{WHILE #{@cond} #{@block}}"

AST.register class CONTINUE extends AST
  @type: 'continue'
  toString: () -> 
    "{CONTINUE}"

AST.register class SWITCH extends AST
  @type: 'switch'
  constructor: (@cond, @cases = []) ->
  toString: () ->
    "{SWITCH #{@cond} #{@cases}}"

AST.register class CASE extends AST
  @type: 'case'
  constructor: (@cond, @exp) ->
  toString: () ->
    "{CASE #{@cond} #{@exp}}"

AST.register class DEFAULTCASE extends AST
  @type: 'defaultCase'
  constructor: (@exp) ->
  toString: () ->
    "{DEFAULT #{@exp}}"

module.exports = AST
