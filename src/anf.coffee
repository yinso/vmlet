AST = require './ast'
Hashmap = require './hashmap'
util = require './util'
T = require './transformer'
TR = require './trace'

class Environment 
  @make: () -> 
    new @()
  constructor: () -> 
    @inner = new Hashmap()
    @temp = 0
  has: (key) -> 
    @inner.has key 
  get: (key) -> 
    @inner.get key
  set: (key, val) -> 
    @inner.set key, val
  alias: (key) -> 
    if @has key 
      @get key
    else
      ref = AST.ref key # AST.symbol(key.value) # this would have been a new symbol...
      @set key, ref
      ref # this returns a reference... 
  gensym: (sym = null) ->
    if sym 
      AST.symbol "#{sym.value}$#{@temp++}"
    else
      AST.symbol "_$#{@temp++}"
  defineTemp: (ast) -> 
    sym = @gensym()
    ref = @alias sym
    ref.value = ast
    ref
  pushEnv: () -> 
    newEnv = @constructor.make()
    newEnv.prev = @ 
    newEnv
  toString: () -> 
    "<env>"

class AnfRegistry
  @transform: (ast) -> 
    if not @reg
      @reg = new @()
    @reg.transform ast 
  transform: (ast, env = Environment.make(), block = AST.block()) -> 
    res = @runInner ast, env, block
    T.transform res
  runInner: (ast, env, block = AST.block()) ->
    res = @run ast, env, block 
    @_normalize res, block
    
  _normalize: (ast, block) -> 
    switch ast.type()
      when 'toplevel', 'module'
        ast 
      else
        @_normalizeBlock block
  _normalizeBlock: (ast) -> 
    items = []
    for item, i in ast.items
      if i < ast.items.length - 1 
        switch item.type()
          when 'number', 'string', 'bool', 'null', 'unit', 'proxyval', 'ref', 'symbol'
            item
          else
            items.push item
      else
        items.push item 
    AST.block items
  run: (ast, env, block = AST.block()) -> 
    type = "_#{ast.type()}"
    if @[type]
      @[type](ast, env, block)
    else
      throw new Error("anf.unknown_type: #{ast.type()}")
  assign: (ast, env, block) ->
    sym = env.defineTemp ast 
    block.push AST.local(sym, ast)
    sym
  _number: (ast, env, block) -> 
    block.push ast 
  _string: (ast, env, block) -> 
    block.push ast 
  _bool: (ast, env, block) -> 
    block.push ast 
  _null: (ast, env, block) -> 
    block.push ast 
  _unit: (ast, env, block) -> 
    block.push ast 
  _symbol: (ast, env, block) -> 
    ref = env.alias ast
    ref.name
  _ref: (ast, env, block) -> 
    ref = env.alias ast.name
    ref.value = ast.value
    block.push ref
  _binary: (ast, env, block) ->
    lhs = @run ast.lhs, env, block
    rhs = @run ast.rhs, env, block
    @assign AST.binary(ast.op, lhs, rhs), env, block
  _if: (ast, env, block) ->
    cond = @run ast.cond, env, block
    thenAST = @runInner ast.then, env
    elseAST = @runInner ast.else, env
    @assign AST.if(cond, thenAST, elseAST), env, block
  _block: (ast, env, block) ->
    for i in [0...ast.items.length - 1]
      @run ast.items[i], env, block
    res = @run ast.items[ast.items.length - 1], env, block
    res
  _define: (ast, env, block) ->
    ref = @run ast.name, env, block
    if ref.type() == 'symbol'
      ref = env.get ref
    res = @runInner ast.value, env
    #TR.log '--anf.define', ast, ref, res
    if res.type() == 'block'
      for exp, i in res.items
        if i < res.items.length - 1 
          block.push exp
        else
          switch exp.type()
            when 'define', 'local'
              ref.value = exp.value
              #TR.log '--anf.define.last.define', ref.name, exp.value
              block.push AST.define(ref, exp.value)
            else
              ref.value = exp
              block.push AST.define(ref, exp)
    else
      ref.value = exp
      block.push AST.define(ref, res)
  _local: (ast, env, block) ->
    ref = @run ast.name, env, block
    if ref.type() == 'symbol'
      ref = env.get ref
    res = 
      if ast.value 
        @runInner ast.value, env
      else
        ast.value 
    if res?.type() == 'block'
      for exp, i in res.items 
        if i < res.items.length - 1 
          block.push exp 
        else
          switch exp.type()
            when 'define', 'local'
              ref.value = exp.value
              return block.push AST.local(ref, exp.value)
            else
              ref.value = exp
              return block.push AST.local(ref, exp)
    else
      ref.value = res
      cloned = AST.local ref, res 
      block.push cloned
  _object: (ast, env, block) ->
    keyVals = 
      for [key, val] in ast.value
        v = @run val, env, block
        [key, v]
    @assign AST.object(keyVals), env, block
  _array: (ast, env, block) ->
    items = 
      for v in ast.value
        @run v, env, block
    @assign AST.array(items), env, block
  _member: (ast, env, block) ->
    head = @run ast.head, env, block
    @assign AST.member(head, ast.key), env, block
  _funcall: (ast, env, block) ->
    funcall = @run ast.funcall, env, block
    args = 
      for arg in ast.args
        @run arg, env, block
    ast = AST.funcall funcall, args
    @assign ast, env, block
  _taskcall: (ast, env, block) ->
    funcall = @run ast.funcall, env, block
    args = 
      for arg in ast.args
        @run arg, env, block
    @assign AST.taskcall(funcall, args), env, block
  @_proc: (type) ->
    (ast, env, block) ->
      #newEnv = Environment.pushEnv env
      newEnv = env
      ref = 
        if ast.name 
          @run ast.name, newEnv 
        else
          undefined
      params = 
        for p in ast.params
          @run p, newEnv 
      proc = AST.make type, ref, params
      if ref 
        ref.value = proc 
      proc.body = @runInner ast.body, newEnv 
      # this free variables needs to be handled as early as possible or we will need to have it passed 
      # at every stage... 
      # another way is to handle it as late as possible, i.e. generate it only when needed... 
      # in that case we will lose the information we have during resolver...
      proc.frees = 
        for ref in ast.frees 
          @run ref, newEnv
      block.push T.transform(proc)
  _procedure: @_proc('procedure')
  _task: @_proc('task')
  _param: (ast, env, block) -> 
    name = @run ast.name, env, block
    param = AST.param name, ast.type, ast.default 
    ref = env.alias name 
    ref.value = param 
    param
  _throw: (ast, env, block) ->
    exp = @run ast.value, env, block
    block.push AST.throw exp
  _catch: (ast, env, block) ->
    #newEnv = Environment.pushEnv env
    newEnv = env
    param = @run ast.param, newEnv
    body = @run ast.body, newEnv
    AST.catch param, body
  _finally: (ast, env, block) ->
    #newEnv = Environment.pushEnv env
    newEnv = env
    body = @transform ast.body, newEnv
    AST.finally body
  _try: (ast, env, block) ->
    #newEnv = Environment.pushEnv env
    newEnv = env
    body = @run ast.body, newEnv
    catches = 
      for c in ast.catches
        @_catch c, env, block
    fin = 
      if ast.finally 
        @_finally ast.finally, env, block
      else
        null
    block.push AST.try(body, catches, fin)
  _import: (ast, env, block) ->
    defines = 
      for binding in ast.bindings
        @run ast.define(binding), env, block
    block.push AST.unit()
  _export: (ast, env, block) ->
    bindings = 
      for binding in ast.bindings 
        spec = @run binding.spec, env, block
        AST.binding spec, binding.as
    block.push AST.export bindings
  _let: (ast, env, block) ->
    #newEnv = Environment.pushEnv env
    newEnv = env
    defines = []
    for define in ast.defines
      res = @run define, newEnv
      if res.type() == 'block'
        for exp in res.items
          block.push exp
      else
        block.push res
      #block.push res.items[0]
    body = @run ast.body , newEnv
    if body.type() == 'block'
      for exp in body.items 
        block.push exp 
    else
      block.push body
  _toplevel: (ast, env, block) -> 
    body = @runInner ast.body, env, block 
    ast.clone AST.return(body)
  _module: (ast, env, block) -> 
    body = @runInner ast.body, env, block 
    ast.clone AST.return(body)
  
module.exports = AnfRegistry
