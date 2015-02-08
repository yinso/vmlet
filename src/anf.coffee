# ANF standards a-normal form.
# it is the precursor for compiling into CPS transformation.

loglet = require 'loglet'
errorlet = require 'errorlet'
AST = require './ast'
baseEnv = require './baseenv'
Environment = require './environment'
ParamList = require './parameter'


class LexicalEnvironment extends Environment
  @defaultPrefix = '___'
  @fromParams: (params, prev = baseEnv) ->
    env = new @ {}, prev
    for param in params
      gensym = env.gensym param.name
      env.defineRef gensym
      env.mapLocal param.name, gensym
      #env.defineRef param.name
    env
  constructor: (inner = {}, prev = null) ->
    super inner, prev
    @genids = 
      if @prev instanceof @constructor
        @prev.genids
      else
        {}
    @localMap = {}
  mapParam: (param) ->
    sym = @defineRef param.name
    AST.make 'param', sym, param.type, param.default
  defineRef: (name) ->
    sym = @gensym name
    super sym
    @mapLocal name, sym
    sym
  has: (key) ->
    if @hasLocal key
      true
    else 
      super key
  get: (key) ->
    if @hasLocal key
      super @localMap[key]
    else
      super key
  mapLocal: (name, local) ->
    @localMap[name] = local
  hasLocal: (name) ->
    @localMap.hasOwnProperty(name)
  getLocal: (name) ->
    @localMap[name]
  gensym: (prefix = LexicalEnvironment.defaultPrefix) ->
    if not @genids.hasOwnProperty(prefix)
      @genids[prefix] = 0
    "#{prefix}$#{@genids[prefix]++}"
  assign: (val, sym = LexicalEnvironment.defaultPrefix) ->
    varName = @gensym sym
    @define varName, val
    varName


types = {}

BLOCK = AST.get 'block'

class ANF extends BLOCK
  @type: 'anf'
  @genids: {}
  @fromEnv: (env = baseEnv) ->
    new @([], (if env instanceof LexicalEnvironment then env else new LexicalEnvironment({}, env)))
  constructor: (items = [], env = new LexicalEnvironment({}, baseEnv)) ->
    super items
    @env = env
  mapLocal: (name, local) ->
    @env.mapLocal name, local
  hasLocal: (name) ->
    @env.hasLocal name
  getLocal: (name) ->
    local = @env.getLocal name
    @env.get local
  gensym: (prefix = LexicalEnvironment.defaultPrefix) ->
    if not @constructor.genids.hasOwnProperty(prefix)
      @constructor.genids[prefix] = 0
    "_#{prefix}$#{@constructor.genids[prefix]++}"
  assign: (val, sym = LexicalEnvironment.defaultPrefix) ->
    varName = @env.assign val, sym
    @items.push AST.make('define', varName, val)
    AST.make 'symbol', varName
  scalar: (ast) ->
    @items.push ast
    ast
  define: (name, val) ->
    @assign AST.make('define', name, val)
  binary: (op, lhs, rhs, sym = LexicalEnvironment.defaultPrefix) ->
    # we want to propagate the define down t
    # we should have an AST for this??? 
    ast = AST.make 'binary', op, lhs, rhs
    @assign ast, sym
  if: (cond, thenE, elseE, sym = LexicalEnvironment.defaultPrefix) ->
    ast = AST.make 'if', cond, thenE, elseE
    @assign ast, sym
  object: (keyVals, sym = LexicalEnvironment.defaultPrefix) ->
    ast = AST.make 'object', keyVals
    @assign ast, sym
  array: (items, sym = LexicalEnvironment.defaultPrefix) ->
    ast = AST.make 'array', items
    @assign ast, sym
  member: (head, key, sym = LexicalEnvironment.defaultPrefix) ->
    ast = AST.make 'member', head, key
    @assign ast, sym
  funcall: (funcall, args, sym = LexicalEnvironment.defaultPrefix) ->
    ast = AST.make 'funcall', funcall, args
    @assign ast, sym
  procedure: (name, params, body, sym = LexicalEnvironment.defaultPrefix) ->
    ast = AST.make 'procedure', name, params, body
    @assign ast, sym
  throw: (exp, sym = LexicalEnvironment.defaultPrefix) ->
    ast = AST.make 'throw', exp
    @assign ast, sym
  normalize: () ->
    loglet.log 'ANF.normalize', @
    # within normalize is where we are going to do the damage...
    # 1 - make sure we stripe out all of the scalar only items (unless it's the only one!)
    @stripScalars()
    @propagateReturn()
  stripScalars: () ->
    # we will strip all scalars unless it happens to be the last one...
    items = []
    for item, i in @items
      if i < @items.length - 1
        if item.type() == 'define'
          items.push @normalizeDefine(item)
        else if item.type() == 'throw'
          items.push item
      else
        items.push item
    @items = items
  normalizeDefine: (ast) ->
    name = ast.name
    valAST = ast.val
    switch valAST.type()
      when 'number', 'string', 'bool', 'null', 'symbol', 'binary', 'funcall', 'member', 'procedure', 'array', 'object', 'ref'
        return ast
      else
        @_normalizeDefine name, valAST
  _normalizeDefine: (name, ast) ->
    loglet.log '_normalizeDefine', name, ast
    switch ast.type()
      when 'if'
        thenE = @_normalizeDefine name, ast.then
        elseE = @_normalizeDefine name, ast.else
        AST.make 'if', ast.if, thenE, elseE
      when 'block'
        items = 
          for item, i in ast.items
            if i < ast.items.length - 1
              item
            else
              @_normalizeDefine name, item
        AST.make 'block', items
      when 'anf'
        items = 
          for item, i in ast.items
            if i < ast.items.length - 1
              item
            else
              @_normalizeDefine name, item
        new ANF items, @env
      else
        throw errorlet.create {error: 'ANF._normalizeReturn:unsupported_ast_type', type: ast.type()}
  propagateReturn: () ->
    ast = @items.pop() # the last item is the only one that's in return position.
    @items.push @_propagateReturn ast
  _propagateReturn: (ast) ->
    switch ast.type()
      when 'define'
        @_propagateReturn ast.val
      when 'number', 'string', 'bool', 'null', 'symbol', 'binary', 'funcall', 'member', 'procedure', 'array', 'object', 'ref'
        AST.make('return', ast)
      when 'if'
        thenE = @_propagateReturn ast.then
        elseE = @_propagateReturn ast.else
        AST.make 'if', ast.if, thenE, elseE
      when 'block'
        items = 
          for item, i in ast.items
            if i < ast.items.length - 1
              item
            else
              @_propagateReturn item
        AST.make 'block', items
      when 'anf'
        items = 
          for item, i in ast.items
            if i < ast.items.length - 1
              item
            else
              @_propagateReturn item
        new ANF items, @env
      when 'return'
        ast
      when 'throw'
        ast
      else
        throw errorlet.create {error: 'ANF.propagateReturn:unsupported_ast_type', type: ast.type()}
  toString: () ->
    buffer = []
    buffer.push '{ANF'
    for stmt in @items
      buffer.push "  #{stmt}"
    buffer.push '}'
    buffer.join '\n'


register = (ast, transformer) ->
  if types.hasOwnProperty(ast.type)
    throw errorlet.create {error: 'anf_duplicate_ast_type', type: ast.type}
  else
    types[ast.type] = transformer
  
get = (ast) ->
  if types.hasOwnProperty(ast.constructor.type)
    types[ast.constructor.type]
  else
    throw errorlet.create {error: 'anf_unsupported_ast_type', type: ast.constructor.type}

override = (ast, transformer) ->
  types[ast.type] = transformer

transform = (ast, env = baseEnv, anf = ANF.fromEnv(env), level = 0) ->
  loglet.log '--TRANSFORM', ast, anf, level
  _transform ast, anf, level
  anf.normalize()
  anf

_transform = (ast, anf = ANF.fromEnv(baseEnv), level = 0) ->
  loglet.log '--transform', ast, anf, level
  type = ast.constructor.type
  if types.hasOwnProperty(type)
    transformer = get ast
    transformer ast, anf, level
  else
    throw errorlet.create {error: 'anf_unsupported_ast_type', type: type}

# by default this probably should never be called? 
transformScalar = (ast, anf, level) ->
  anf.scalar ast

register AST.get('number'), transformScalar
register AST.get('bool'), transformScalar
register AST.get('null'), transformScalar
register AST.get('string'), transformScalar

transformBinary = (ast, anf, level) ->
  lhs = _transform ast.lhs, anf, level
  rhs = _transform ast.rhs, anf, level
  anf.binary ast.op, lhs, rhs
  
register AST.get('binary'), transformBinary

transformIf = (ast, anf, level) ->
  loglet.log '--transformIf', ast, anf, level
  cond = _transform ast.if, anf, level
  thenAST = transform ast.then, anf.env, ANF.fromEnv(anf.env), level
  elseAST = transform ast.else, anf.env, ANF.fromEnv(anf.env), level
  anf.if cond, thenAST, elseAST

register AST.get('if'), transformIf

transformBlock = (ast, anf, level) ->
  for i in [0...ast.items.length - 1]
    _transform ast.items[i], anf, level 
  _transform ast.items[ast.items.length - 1], anf, level

register AST.get('block'), transformBlock

transformDefine = (ast, anf, level) ->
  loglet.log 'transformDefine', ast
  res = _transform ast.val, anf, level
  anf.define ast.name, res
  #key = anf.mapLocal ast.name, res
  #loglet.log 'transformDefine.done', ast.name, res, key
  #key

register AST.get('define'), transformDefine

transformObject = (ast, anf, level) ->
  keyVals = 
    for [key, val] in ast.val
      v = _transform val, anf, level
      [key, v]
  anf.object keyVals

register AST.get('object'), transformObject

transformArray = (ast, anf, level) ->
  items = 
    for v in ast.val
      _transform v, anf, level
  anf.array items

register AST.get('array'), transformArray

transformMember = (ast, anf, level) ->
  head = _transform ast.head, anf, level
  anf.member head, ast.key

register AST.get('member'), transformMember

transformIdentifier = (ast, anf, level) ->
  loglet.log '--transformIdentifier', ast, anf, level
  if anf.env.has ast.val 
    anf.scalar anf.env.get ast.val
  else if anf.hasLocal ast.val
    anf.getLocal(ast.val)
  else
    throw errorlet.create {error: 'ANF.transform:unknown_identifier', id: ast.val}  
  
register AST.get('symbol'), transformIdentifier

transformFuncall = (ast, anf, level) ->
  loglet.log '--transformFuncall', ast, anf, level
  args = 
    for arg in ast.args
      _transform arg, anf, level
  funcall = _transform ast.funcall, anf, level
  anf.funcall funcall, args

register AST.get('funcall'), transformFuncall

transformParam = (ast, anf, level) ->
  ast
  
register AST.get('param'), transformParam

transformProcedure = (ast, anf, level) ->
  newEnv = new LexicalEnvironment {}, anf.env
  name = 
    if ast.name
      newEnv.defineRef ast.name
    else
      undefined
  params = 
    for param in ast.params
      newEnv.mapParam param
  body = transform ast.body, newEnv, ANF.fromEnv(newEnv), level + 1
  anf.procedure name, params, body
  ###
  newEnv = LexicalEnvironment.fromParams ast.params, anf.env
  if ast.name
    newEnv.defineRef ast.name
  body = transform ast.body, newEnv
  params = 
    for param in ast.params
      local = newEnv.getLocal param.name
      AST.make 'param', local
  anf.procedure ast.name, params, body
  ###

register AST.get('procedure'), transformProcedure

transformThrow = (ast, anf, level) ->
  exp = _transform ast.val, anf, level
  anf.throw exp
  
register AST.get('throw'), transformThrow

module.exports = 
  register: register
  isANF: (v) -> v instanceof ANF
  ANF: ANF
  get: get
  override: override
  transform: transform





