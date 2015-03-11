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
    @get @localMap[name]
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
    @env.getLocal name
  pushEnv: () ->
  popEnv: () ->
  assign: (val, sym = LexicalEnvironment.defaultPrefix) ->
    varName = @env.assign val, sym
    @items.push AST.make('tempvar', varName, val)
    AST.make 'symbol', varName
  push: (ast) ->
    @items.push ast
    ast
  scalar: (ast) ->
    @push ast
  define: (name, val) ->
    @env.define name, val
    @items.push AST.make('define', name, val)
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
  taskcall: (funcall, args, sym = LexicalEnvironment.defaultPrefix) ->
    ast = AST.make 'taskcall', funcall, args
    @assign ast, sym
  funcall: (funcall, args, sym = LexicalEnvironment.defaultPrefix) ->
    ast = AST.make 'funcall', funcall, args
    @assign ast, sym
  procedure: (name, params, body, sym = LexicalEnvironment.defaultPrefix) ->
    ast = AST.make 'procedure', name, params, body
    @assign ast, sym
  task: (name, params, body, sym = LexicalEnvironment.defaultPrefix) ->
    ast = AST.make 'task', name, params, body
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
        if item.type() == 'tempvar'
          items.push @normalizeTempVar(item)
        else if item.type() == 'throw' 
          items.push item
        else if item.type() == 'define'
          items.push item
      else
        items.push item
    @items = items
  normalizeTempVar: (ast) ->
    name = ast.name
    valAST = ast.val
    switch valAST.type()
      when 'number', 'string', 'bool', 'null', 'symbol', 'binary', 'funcall', 'member', 'procedure', 'array', 'object', 'ref', 'proxyval', 'taskcall', 'task'
        return ast
      else
        @_normalizeTempVar name, valAST
  _normalizeTempVar: (name, ast) ->
    loglet.log '_normalizeTempVar', name, ast
    switch ast.type()
      when 'if'
        thenE = @_normalizeTempVar name, ast.then
        elseE = @_normalizeTempVar name, ast.else
        AST.make 'if', ast.if, thenE, elseE
      when 'block'
        items = 
          for item, i in ast.items
            if i < ast.items.length - 1
              item
            else
              @_normalizeTempVar name, item
        AST.make 'block', items
      when 'anf'
        items = 
          for item, i in ast.items
            if i < ast.items.length - 1
              item
            else
              @_normalizeTempVar name, item
        new ANF items, @env
      else
        throw errorlet.create {error: 'ANF._normalizeReturn:unsupported_ast_type', type: ast.type()}
  propagateReturn: () ->
    ast =  @_propagateReturn @items.pop()# the last item is the only one that's in return position.
    @items.push ast 
    if ast.type() == 'define'
      @items.push AST.make('return', AST.make('proxyval', '_rt.unit'))
  _propagateReturn: (ast) ->
    switch ast.type()
      when 'tempvar'
        @_propagateReturn ast.val
      when 'number', 'string', 'bool', 'null', 'symbol', 'binary', 'funcall', 'member', 'procedure', 'array', 'object', 'ref', 'proxyval', 'task', 'taskcall'
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
      when 'try'
        @_propagateReturnTry ast
      when 'catch'
        @_propagateReturnCatch ast
      when 'define'
        ast
      else
        throw errorlet.create {error: 'ANF.propagateReturn:unsupported_ast_type', type: ast.type()}
  _propagateReturnCatch: (ast) ->
    loglet.log 'ANF._propagateReturnCatch', ast
    body = @_propagateReturn ast.body
    AST.make 'catch', ast.param, body
  _propagateReturnTry: (ast) ->
    loglet.log 'ANF._propagateReturnTry', ast
    body = @_propagateReturn ast.body
    catches = 
      for c in ast.catches
        @_propagateReturn c
    AST.make 'try', body, catches, ast.finally
  toString: () ->
    buffer = []
    buffer.push '{ANF'
    for stmt in @items
      buffer.push "  #{stmt}"
    buffer.push '}'
    buffer.join '\n'

AST.register ANF

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
  loglet.log '--anf.transform', ast, anf, level
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
  loglet.log '--anf.transformBinary', ast
  lhs = _transform ast.lhs, anf, level
  rhs = _transform ast.rhs, anf, level
  anf.binary ast.op, lhs, rhs
  
register AST.get('binary'), transformBinary

transformIf = (ast, anf, level) ->
  loglet.log '--anf.transformIf', ast, anf, level
  cond = _transform ast.if, anf, level
  thenAST = transform ast.then, anf.env, ANF.fromEnv(anf.env), level
  thenAST = 
    if thenAST.items.length == 1
      thenAST.items[0]
    else
      thenAST
  elseAST = transform ast.else, anf.env, ANF.fromEnv(anf.env), level
  elseAST = 
    if elseAST.items.length == 1
      elseAST.items[0]
    else
      elseAST
  anf.if cond, thenAST, elseAST

register AST.get('if'), transformIf

transformBlock = (ast, anf, level) ->
  anf.pushEnv()
  for i in [0...ast.items.length - 1]
    _transform ast.items[i], anf, level + 1
  res = _transform ast.items[ast.items.length - 1], anf, level
  anf.popEnv()
  res
register AST.get('block'), transformBlock

transformDefine = (ast, anf, level) ->
  loglet.log 'transformDefine', ast, level
  if level > 0 
    transformTempVar ast, anf, level
  else
    res = _transform ast.val, anf, level
    # this define will keep the name *AS IS*...
    anf.define ast.name, res
  #key = anf.mapLocal ast.name, res
  #loglet.log 'transformDefine.done', ast.name, res, key
  #key

register AST.get('define'), transformDefine

# this ought not be directly used outside... but we will see...
transformTempVar = (ast, anf, level) ->
  res = _transform ast.val, anf, level
  local = anf.assign res, ast.name
  anf.mapLocal ast.name, local.val
  local
  # this define will keep the name *AS IS*...
  #anf.define ast.name, res

register AST.get('tempvar'), transformTempVar

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
  loglet.log '--anf.transformIdentifier', ast, anf.env, level
  if anf.hasLocal ast.val
    anf.scalar anf.getLocal(ast.val)
  else if anf.env.has ast.val 
    loglet.log '--anf.transformIdentifier.env.has', ast, anf.env.get(ast.val)
    anf.scalar anf.env.get ast.val
  else
    throw errorlet.create {error: 'ANF.transform:unknown_identifier', id: ast.val}  
  
register AST.get('symbol'), transformIdentifier

transformFuncall = (ast, anf, level) ->
  loglet.log '--anf.transformFuncall', ast, anf, level
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

register AST.get('procedure'), transformProcedure

transformTask = (ast, anf, level) ->
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
  anf.task name, params, body

register AST.get('task'), transformTask

transformTaskcall = (ast, anf, level) ->
  loglet.log '--anf.transformTaskcall', ast, anf, level
  args = 
    for arg in ast.args
      _transform arg, anf, level
  funcall = _transform ast.funcall, anf, level
  anf.taskcall funcall, args

register AST.get('taskcall'), transformTaskcall

transformThrow = (ast, anf, level) ->
  exp = _transform ast.val, anf, level
  anf.push AST.make 'throw', exp
  
register AST.get('throw'), transformThrow

transformCatch = (ast, anf, level) ->
  loglet.log '--anf.transformCatch', ast
  newEnv = new LexicalEnvironment {}, anf.env
  param = newEnv.mapParam ast.param
  body = transform ast.body, newEnv, ANF.fromEnv(newEnv), level + 1
  AST.make 'catch', param, body

register AST.get('catch'), transformCatch

transformFinally = (ast, anf, level) ->
  loglet.log '--anf.transformFinally', ast
  body = _transform ast.body, anf, level + 1
  AST.make 'finally', body

register AST.get('finally'), transformFinally

transformTry = (ast, anf, level) ->
  loglet.log '--anf.transformTry', ast
  newEnv = new LexicalEnvironment {}, anf.env
  body = transform ast.body, newEnv, ANF.fromEnv(newEnv), level + 1
  catches = 
    for c in ast.catches
      transformCatch c, anf, level
  fin = 
    if ast.finally instanceof AST
      transformFinally ast.finally, anf, level
    else
      null
  loglet.log '--anf.transformTry', body, catches, fin
  anf.push AST.make 'try', body, catches, fin

register AST.get('try'), transformTry

module.exports = 
  register: register
  isANF: (v) -> v instanceof ANF
  ANF: ANF
  get: get
  override: override
  transform: transform





