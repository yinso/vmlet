AST = require './ast'
Environment = require './symboltable'
T = require './transformer'

types = {}

register = (type, transformer) ->
  if types.hasOwnProperty(type.type)
    throw new Error("ANF.duplicate_type: #{type.type}")
  types[type.type] = transformer 

get = (ast) ->
  if types.hasOwnProperty(ast.type())
    types[ast.type()]
  else
    throw new Error("ANF.unknown_type: #{ast.type()}")

transform = (ast, env = new Environment(), block = AST.block()) -> 
  res = _transInner ast, env, block
  console.log 'ANF._trans', ast, res
  T.transform res

_normalize = (ast, block) -> 
  switch ast.type()
    when 'toplevel', 'module'
      ast 
    else
      _normalizeBlock block

_transInner = (ast, env, block = AST.block()) -> 
  res = _trans ast, env, block 
  _normalize res, block

_normalizeBlock = (ast) -> 
  items = []
  console.log 'ANF.normalizeBlock', ast
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

_trans = (ast, env, block = AST.block()) -> 
  trans = get ast
  trans ast, env , block

assign = (ast, env, block) ->
  sym = env.defineTemp ast 
  block.push AST.local(sym, ast)
  sym

_scalar = (ast, env, block) -> 
  block.push ast 

register AST.get('number'), _scalar
register AST.get('string'), _scalar
register AST.get('bool'), _scalar
register AST.get('null'), _scalar
register AST.get('unit'), _scalar
register AST.get('proxyval'), _scalar

_alias = (ast, env) -> 
  switch ast.type()
    when 'ref'
      if env.has ast.name 
        env.get ast.name 
      else
        env.define ast.name, ast.value 
    when 'symbol'
      if env.has ast 
        env.get ast 
      else
        env.define ast 
    else
      throw new Error("ANF.alias:unsuppoted_type: #{ast}")

_symbol = (ast, env, block) -> 
  _alias ast, env

register AST.get('symbol'), _symbol

_ref = (ast, env, block) -> 
  ref = _alias ast, env
  block.push ref

register AST.get('ref'), _ref

_binary = (ast, env, block) ->
  lhs = _trans ast.lhs, env, block
  rhs = _trans ast.rhs, env, block
  assign AST.binary(ast.op, lhs, rhs), env, block
  
register AST.get('binary'), _binary

_if = (ast, env, block) ->
  cond = _trans ast.cond, env, block
  thenAST = _transInner ast.then, env
  elseAST = _transInner ast.else, env
  assign AST.if(cond, thenAST, elseAST), env, block

register AST.get('if'), _if

_block = (ast, env, block) ->
  for i in [0...ast.items.length - 1]
    _trans ast.items[i], env, block
  res = _trans ast.items[ast.items.length - 1], env, block
  res

register AST.get('block'), _block

_define = (ast, env, block) ->
  ref = _alias ast.name, env, block
  res = _transInner ast.value, env
  console.log 'anf.define', ast, res
  if res.type() == 'block'
    for exp, i in res.items
      if i < res.items.length - 1 
        block.push exp
      else
        switch exp.type()
          when 'define', 'local'
            ref.value = exp.value
            block.push AST.define(ref, exp.value)
          else
            ref.value = exp
            block.push AST.define(ref, exp)
  else
    ref.value = exp
    block.push AST.define(ref, res)

register AST.get('define'), _define

_local = (ast, env, block) ->
  ref = _alias ast.name, env, block
  res = 
    if ast.value 
      _transInner ast.value, env
    else
      ast.value 
  if res.type() == 'block'
    for exp, i in res.items 
      if i < res.items.length - 1 
        block.push exp 
      else
        switch exp.type()
          when 'define', 'local'
            ref.value = exp.value
            block.push AST.local(ref, exp.value)
          else
            ref.value = exp
            block.push AST.local(ref, exp)
  else
    ref.value = res
    cloned = AST.local ref, res 
    block.push cloned 

register AST.get('local'), _local

_object = (ast, env, block) ->
  keyVals = 
    for [key, val] in ast.value
      v = _trans val, env, block
      [key, v]
  assign AST.object(keyVals), env, block

register AST.get('object'), _object

_array = (ast, env, block) ->
  items = 
    for v in ast.value
      _trans v, env, block
  assign AST.array(items), env, block

register AST.get('array'), _array

_member = (ast, env, block) ->
  head = _trans ast.head, env, block
  assign AST.member(head, ast.key), env, block

register AST.get('member'), _member

_funcall = (ast, env, block) ->
  #loglet.log '--anf._funcall', ast, block
  args = 
    for arg in ast.args
      _trans arg, env, block
  funcall = _trans ast.funcall, env, block
  console.log 'ANF.funcall.funcall', funcall
  ast = AST.funcall funcall, args
  assign ast, env, block

register AST.get('funcall'), _funcall

_taskcall = (ast, env, block) ->
  #loglet.log '--anf._taskcall', ast, block
  args = 
    for arg in ast.args
      _trans arg, env, block
  funcall = _trans ast.funcall, env, block
  assign AST.taskcall(funcall, args), env, block

register AST.get('taskcall'), _taskcall

_proc = (type) ->
  (ast, env, block) ->
    newEnv = new Environment env
    ref = 
      if ast.name 
        _trans ast.name, newEnv 
      else
        undefined
    params = 
      for p in ast.params
        _trans p, newEnv 
    proc = AST.make type, ref, params
    if ref 
      ref.value = proc 
    proc.body = _transInner ast.body, newEnv 
    console.log 'ANF.proc.trans', ref, ref.value
    block.push T.transform(proc)

register AST.get('procedure'), _proc('procedure')
register AST.get('task'), _proc('task')

_param = (ast, env, block) -> 
  ref = _alias ast.name, env, block
  ref.value = AST.param ref, ast.type, ast.default 
  ref.value

register AST.get('param'), _param 

_throw = (ast, env, block) ->
  exp = _trans ast.value, env, block
  block.push AST.throw exp
  
register AST.get('throw'), _throw

_catch = (ast, env, block) ->
  newEnv = new Environment env
  param = _trans ast.param, newEnv
  body = _trans ast.body, newEnv
  AST.catch param, body

register AST.get('catch'), _catch 

_finally = (ast, env, block) ->
  newEnv = new Environment env
  body = transform ast.body, newEnv
  AST.finally body

_try = (ast, env, block) ->
  newEnv = new Environment env
  body = _trans ast.body, newEnv
  catches = 
    for c in ast.catches
      _catch c, env, block
  fin = 
    if ast.finally 
      _finally ast.finally, env, block
    else
      null
  block.push AST.try(body, catches, fin)

register AST.get('try'), _try

_import = (ast, env, block) ->
  defines = 
    for binding in ast.bindings
      #_trans AST.define(binding.as, ast.proxy(binding)), env, block
      _trans ast.define(binding), env, block
    #for define in ast.defines()
    #  _trans define, env, block
  block.push AST.unit()

register AST.get('import'), _import

_export = (ast, env, block) ->
  bindings = 
    for binding in ast.bindings 
      spec = _trans binding.spec, env, block
      AST.binding spec, binding.as
  block.push AST.export bindings

register AST.get('export'), _export

_let = (ast, env, block) ->
  newEnv = new Environment env
  defines = []
  for define in ast.defines
    res = _trans define, newEnv
    for exp in res.items
      block.push exp
    #block.push res.items[0]
  body = _trans ast.body , newEnv
  if body.type() == 'block'
    for exp in body.items 
      block.push exp 
  else
    block.push body

register AST.get('let'), _let

_toplevel = (ast, env, block) -> 
  body = _transInner ast.body, env, block 
  ast.clone AST.return(body)

register AST.get('toplevel'), _toplevel

_module = (ast, env, block) -> 
  body = _transInner ast.body, env, block 
  ast.clone AST.return(body)

register AST.get('module'), _module

module.exports = 
  register: register 
  get: get 
  transform: transform 
