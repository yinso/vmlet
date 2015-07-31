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

class CloneRegistry
  @transform: (ast) -> 
    if not @reg 
      @reg = new @()
    @reg.transform ast 
  constructor: () -> 
  transform: (ast) -> 
    @run ast, new Environment()
  run: (ast, env) -> 
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
    ref = @run ast.name, env
    # we now have a ref... we 
    cloned = @run ast.value, env 
    ref.value = cloned 
    AST.define ref, cloned 
  _local: (ast, env) -> 
    ref = @run ast.name, env 
    cloned = @run ast.value, env 
    ref.value = cloned 
    AST.local ref, cloned 
  _assign: (ast, env) -> 
    ref = @run ast.name, env 
    cloned = @run ast.value, env 
    ref.value = cloned 
    AST.local ref, cloned 
  _if: (ast, env) -> 
    cond = @run ast.cond, env 
    thenAST = @run ast.then, env
    elseAST = @run ast.else, env 
    AST.if cond, thenAST, elseAST 
  _binary: (ast, env) -> 
    lhs = @run ast.lhs, env 
    rhs = @run ast.rhs, env 
    AST.binary ast.op, lhs, rhs
  _member: (ast, env) -> 
    head = @run ast.head, env 
    key = @run ast.key, env 
    AST.member head, key
  _array: (ast, env) -> 
    items = 
      for item in ast.value 
        @run item, env 
    AST.array items 
  _object: (ast, env) -> 
    keyvals = 
      for [ key , val ] in ast.value 
        [ 
          key 
          @run(val, env)
        ]
    AST.object keyvals
  _block: (ast, env) -> 
    AST.block (for item in ast.items 
        @run item, env) 
  _funcall: (ast, env) -> 
    funcall = @run ast.funcall, env 
    args = 
      for arg in ast.args 
        @run arg, env 
    AST.funcall funcall, args 
  _taskcall: (ast, env) -> 
    taskcall = @run ast.funcall, env 
    args = 
      for arg in ast.args 
        @run arg, env 
    AST.taskcall taskcall, args
  _param: (ast, env) -> 
    name = @run ast.name, env 
    param = AST.param name, ast.paramType, ast.default
    param
  _procedure: (ast, env) -> 
    name = 
      if ast.name 
        @run ast.name, env 
      else
        ast.name 
    params = 
      for param in ast.params 
        @run param, env 
    decl = AST.procedure name, params
    decl.body = @run ast.body, env 
    name.value = decl
    decl
  _task: (ast, env) -> 
    name = 
      if ast.name 
        @run ast.name, env 
      else
        ast.name 
    params = 
      for param in ast.params 
        @run param, env 
    decl = AST.task name, params
    decl.body = @run ast.body, env 
    name.value = decl
    decl
  _return: (ast, env) -> 
    AST.return @run(ast.value, env)

module.exports = CloneRegistry
