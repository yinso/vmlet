vm = require 'vm'
loglet = require 'loglet'
errorlet = require 'errorlet'

Environment = require './environment'
parser = require './parser'
AST = require './ast'
ANF = require './anf'
compiler = require './anfcompiler'
baseEnv = require './baseenv'

Promise = require 'bluebird'

class CompileTimeEnvironment extends Environment
  constructor: (@inner) ->
  has: (key) ->
    @inner.has key
  get: (key) ->
    # we want it to return something that would be of substitute?
    AST.make('funcall', AST.make('member', AST.make('symbol', '_rt'), AST.make('symbol', 'get')), [
      AST.make('string', key)
    ])
  
class Runtime
  constructor: (@baseEnv = baseEnv) ->
    loglet.log 'Runtime.ctor'
    @parser = parser
    @compiler = compiler
    @baseEnv.define 'console', console
    @context = vm.createContext { _rt: @ , console: console , process: process }
    @compileEnv = new CompileTimeEnvironment @baseEnv
  define: (key, val) ->
    @baseEnv.define key, val
  eval: (stmt, cb) ->
    if stmt == ':context'
      return cb null, @context
    else if stmt == ':env'
      return cb null, @baseEnv
    try 
      loglet.log '-------- Runtime.eval =>', stmt
      ast = @parser.parse stmt 
      loglet.log '-------- Runtime.AST =>', ast
      anf = ANF.transform ast, @compileEnv 
      loglet.log '-------- Runtime.ANF =>', anf
      compiled = @compiler.compile anf
      loglet.log '-------- Runtime.compile =>', compiled
      context = vm.createContext {_done: cb, _rt: @}
      vm.runInContext compiled, context
      ###
      switch ast.type()
        when 'define' # our goal is to create the things inside and make a definition.
          @evalDefine ast.name, ast.val, cb
        when 'funcall'
          @evalFuncall ast, cb
        else
          @evalRun ast, cb
      ###
    catch e
      cb e
  get: (key) ->
    @baseEnv.get key
  bind: (obj, func) ->
    (args...) ->
      obj[func] args...
  tail: (func, args...) ->
    if func instanceof Promise
      return func
    #loglet.log '^^^^^^^^^^^^^^^^^^^^ RT.__tail', func, args
    lastArg = args[args.length - 1]
    isLastArgFunc = typeof(lastArg) == 'function' or lastArg instanceof Function
    cb = if isLastArgFunc then lastArg else () ->
    if func.__vmlet?.async
      if isLastArgFunc
        args.pop()
      p = new Promise (ok, fail) ->
        func args..., (err, res) ->
          if err 
            fail err
          else
            ok res 
      p.next = cb
      p
    else
      return {tail: func, args: args, cb: cb}
  result: (v) ->
    {__vmlet_result: v}
    #new Result v
  isResult: (v) ->
    #v instanceof Result
    v?.__vmlet_result or (v != undefined and v != null)
  unbind: (v) ->
    if v?.__vmlet_result
      v.__vmlet_result
    else
      v
  tco: (func, args..., cb) ->
    if not (typeof(func) == 'function' or func instanceof Function)
      cb null, func
    else
      @_tco func, args, cb
  while: (cond, ifTrue, ifFalse) ->
    self = @
    return self.tail cond, (err, res) ->
      if err
        return self.tail ifFalse, err
      else if not res 
        return self.tail isFalse, null, cb
      else 
        return self.while cond, ifTrue, ifFalse, cb
  _tco: (func, args, cb) ->
    args.push cb 
    tail = {tail: func, args: args, cb: cb}
    while cb != tail.tail
      #loglet.log ',,,,,,,,,,,,,,,,,,,,,,,,,RT._tco', tail
      # what happens with an error here? 
      # if there is an error here it's *unhandled* -> apparently
      try 
        res = tail.tail tail.args...
        if res instanceof Promise
          return @_tcoAsync res, cb
        else if res?.tail and res?.cb
          tail = res 
        else if @isResult(res)
          return cb null, @unbind res
        else
          return cb errorlet.create {error: 'invalid_tco_function_return', value: res}
      catch e 
        return cb e
    return tail.tail tail.args...
  _tcoAsync: (promise, cb) ->
    self = @
    promise.then (res) ->
      self._tco promise.next, [ null , res ], cb
    .catch (err) ->
      self._tco promise.next, [ err , null ], cb
  

module.exports = Runtime
