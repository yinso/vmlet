AST = require './ast'
Hashmap = require './hashmap'
util = require './util'
TR = require './trace'

# what do we want? 
# in many ways we just did something that's quite useless. 
# we want to swap out the symbols, as well as the REFs.
# how do we do that? 
# 1 - we need to 
class Environment 
  constructor: () -> 
    @inner = new Hashmap
      hashCode: util.hashCode 
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
      ref = AST.ref AST.symbol(key.value)
      @set key, ref
      ref # this returns a reference... 

class Registry 
  @transform: (ast) -> 
    if not @reg 
      @reg = new @()
    @reg.transform ast 
  constructor: () -> 
  transform: (ast) -> 
    @_trans ast, new Environment()
  _trans: (ast, env) -> 
    type = "_#{ast.type()}"
    if @[type]
      @[type](ast, env)
    else
      throw new Error("clone:unknown_type: #{ast.type()}")
  _number: (ast, env) -> ast 
  _string: (ast, env) -> ast 
  _bool: (ast, env) -> ast 
  _null: (ast, env) -> ast 
  _unit: (ast, env) -> ast
  _symbol: (ast, env) -> 
    ref = env.alias ast
    ref.name 
  _ref: (ast, env) -> 
    env.alias ast.name 
  _define: (ast, env) -> 
    # first thing is to ref 
    ref = @_trans ast.name, env
    # we now have a ref... we 
    cloned = @_trans ast.value, env 
    ref.value = cloned 
    AST.define ref, cloned 
  _local: (ast, env) -> 
    ref = @_trans ast.name, env 
    cloned = @_trans ast.value, env 
    ref.value = cloned 
    AST.local ref, cloned 
  _assign: (ast, env) -> 
    ref = @_trans ast.name, env 
    cloned = @_trans ast.value, env 
    ref.value = cloned 
    AST.local ref, cloned 
  _if: (ast, env) -> 
    cond = @_trans ast.cond, env 
    thenAST = @_trans ast.then, env
    elseAST = @_trans ast.else, env 
    AST.if cond, thenAST, elseAST 
  _binary: (ast, env) -> 
    lhs = @_trans ast.lhs, env 
    rhs = @_trans ast.rhs, env 
    AST.binary ast.op, lhs, rhs
  _member: (ast, env) -> 
    head = @_trans ast.head, env 
    key = @_trans ast.key, env 
    AST.member head, key
  _array: (ast, env) -> 
    items = 
      for item in ast.value 
        @_trans item, env 
    AST.array items 
  _object: (ast, env) -> 
    keyvals = 
      for [ key , val ] in ast.value 
        [ 
          key 
          @_trans(val, env)
        ]
    AST.object keyvals
  _block: (ast, env) -> 
    AST.block (for item in ast.items 
        @_trans item, env) 
  _funcall: (ast, env) -> 
    funcall = @_trans ast.funcall, env 
    args = 
      for arg in ast.args 
        @_trans arg, env 
    AST.funcall funcall, args 
  _taskcall: (ast, env) -> 
    taskcall = @_trans ast.funcall, env 
    args = 
      for arg in ast.args 
        @_trans arg, env 
    AST.taskcall taskcall, args
  _param: (ast, env) -> 
    name = @_trans ast.name, env 
    param = AST.param name, ast.paramType, ast.default
    param
  _procedure: (ast, env) -> 
    name = 
      if ast.name 
        @_trans ast.name, env 
      else
        ast.name 
    params = 
      for param in ast.params 
        @_trans param, env 
    decl = AST.procedure name, params
    #TR.log '-- procedure.clone.decl', decl
    decl.body = @_trans ast.body, env 
    name.value = decl
    decl
  _task: (ast, env) -> 
    name = 
      if ast.name 
        @_trans ast.name, env 
      else
        ast.name 
    params = 
      for param in ast.params 
        @_trans param, env 
    decl = AST.task name, params
    decl.body = @_trans ast.body, env 
    name.value = decl
    decl
  _return: (ast, env) -> 
    AST.return @_trans(ast.value, env)

module.exports = Registry
