vm = require 'vm'
loglet = require 'loglet'
errorlet = require 'errorlet'

parser = require './parser'
AST = require './ast'
RESOLVER = require './resolver'
require './ret'
CPS = require './cps'
SymbolTable = require './symboltable'
Unit = require './unit'
util = require './util'
TR = require './trace'

esnode = require './esnode'
escodegen = require 'escodegen'

Promise = require 'bluebird'
fs = require 'fs'

class Session
  constructor: (@cb) -> # this is the final callback - it might be passed in along the way...
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
  tco: (func, args...) ->
    funcall = @tail func, args...
    while funcall.func != @cb 
      res = funcall.func funcall.args...
      if @isResult res
        @cb null, @unbind res
      else if res.func and res.args and res.cb 
        return @tcoAsync res.fun, res.args..., res.cb
      else if res.func and res.args
        funcall = res
    @cb null, funcall.args...
  tcoAsync: (func, args..., cb) ->
    # what 
  tail: (func, args...) ->
    {func: func, args: args}
  # the key thing to keep in mind is that every async call is automatically at the tail position...
  # what do we want to do here is to make sure that we can have them hooked correctly...
  async: (func, args..., cb) ->
    {func: func, args: args, cb: cb}

# let's do most of the work in transformations!
# i.e. the compiler should just be something that automates the process...

# compiled time environment and runtime environment are now definition going to be different...
# in order to do so we should retain as much information as possible about the object that is being created.
# when it's being referenced - i.e. keep the high level defintiion of the object 
# something like... 
# 
# in this version we don't really know the object itself... hmmm... 
  
class Runtime
  constructor: (@baseEnv = new SymbolTable()) ->
    loglet.log 'Runtime.ctor'
    @parser = parser
    @AST = AST
#    @defineSync '+', (_rt) -> (a, b) -> a + b
#    @defineSync '-', (_rt) -> (a, b) -> a - b
#    @defineSync '*', (_rt) -> (a, b) -> a * b
#    @defineSync '%', (_rt) -> (a, b) -> a % b
#    @defineSync '>', (_rt) -> (a, b) -> a > b
#    @defineSync '>=', (_rt) -> (a, b) -> a >= b
#    @defineSync '<=', (_rt) -> (a, b) -> a <= b
#    @defineSync '<', (_rt) -> (a, b) -> a < b
#    @defineSync '==', (_rt) -> (a, b) -> a == b
#    @defineSync '!=', (_rt) -> (a, b) -> a != b
#    @defineSync 'isNumber', (_rt) ->
#      (a) -> 
#        typeof(a) == 'number' or a instanceof Number
    ###
    @define 'console', 
      log: @makeSync (_rt) -> 
        (args...) ->
          console.log args...
          Unit.unit
      time: @makeSync (_rt) -> 
        (args...) ->
          console.time args...
          Unit.unit
      timeEnd: @makeSync (_rt) -> 
        (args...) ->
          console.timeEnd args...
          Unit.unit
      debug: @makeSync (_rt) -> 
        (args...) ->
          console.debug args...
          Unit.unit
      error: @makeSync (_rt) -> 
        (args...) ->
          console.error args...
          Unit.unit
    ###
    # now the biggest challenge starts!
    @define AST.symbol('fs'),
      readFile: @makeAsync (_rt) ->
        readFile = _rt.member(fs, 'readFile')
        (args...) ->
          return readFile args...
    @context = vm.createContext { _rt: @ , console: console , process: process }
  unit: Unit.unit
  define: (key, val) ->
    @baseEnv.define key, val
  makeProc: (func, def) -> 
    Object.defineProperty func, '__vmlet',
      value: 
        sync: true
        def: def 
    func
  makeSync: (funcMaker) ->
    func = funcMaker @
    func.__vmlet = {sync: true}
    func
  makeAsync: (funcMaker) ->
    func = funcMaker @
    func.__vmlet = {async: true}
    func
  defineSync: (key, funcMaker) ->
    @define key, @makeSync funcMaker
  defineAsync: (key, funcMaker) ->
    @define key, @makeAsync funcMaker
  compile: (ast) ->
    node = esnode.expression esnode.funcall(esnode.function(null, [], esnode.block([esnode.return(ast.toESNode())])), [])
    #TR.log '--to.esnode', node
    escodegen.generate node
  parse: (stmt) ->
    @parser.parse stmt
  eval: (stmt, cb) ->
    if stmt == ':context'
      return cb null, @context
    else if stmt == ':env'
      return cb null, @baseEnv
    try 
      loglet.log '-------- Runtime.eval =>', stmt
      ast = @parse stmt 
      loglet.log '-------- Runtime.parsed =>', ast
      ast = RESOLVER.transform ast, new SymbolTable(@baseEnv)
      loglet.log '-------- Runtime.transformed =>', ast
      ast = CPS.transform ast
      loglet.log '-------- Runtime.cpsed =>', ast
      compiled = @compile ast
      loglet.log '-------- Runtime.compiled =>', compiled
      compiler = vm.runInContext compiled, @context
      loglet.log '-------- Runtime.evaled =>', compiler
      try 
        compiler @, (err, res) =>
          if err 
            cb err
          else if res instanceof Unit
            cb null
          else if @isResult(res)
            cb null, @unbind(res)
          else
            cb err, res
      catch e
        cb e
    catch e
      cb e
  get: (key) ->
    @baseEnv.get key
  member: (obj, key) ->
    member = obj[key]
    if util.isFunction(member)
      (args...) ->
        obj[key] args...
    else
      member
  promise: (func, args..., cb) ->
    loglet.log '_rt.promise', func, args, cb
    #p = Promise.defer()
    p = new Promise (ok, fail) ->
      func args..., (err, res) ->
        loglet.log '_rt.promise.call', err, res
        if err 
          fail err
        else
          ok res
    #.then (v) -> 
    #  loglet.log '_rt.promise.ok', v
    #  cb null, v
    #.catch (e) -> 
    #  loglet.log '_rt.promise.reject', e
    #  cb e
    p.next = cb
    p
  tailAsync: (func, args..., cb) ->
    {tail: func, args: args, cb: cb}
  tail: (func, args...) ->
    {tail: func, args: args}
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
    # does this part make sense??? not too sure... hmm....
    if not util.isFunction(func)
      if func instanceof Unit
        cb null
      else
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
    if func.__vmlet?.async
      args.push cb 
    funcall = {tail: func, args: args, cb: cb}
    while cb != funcall.tail
      #loglet.log ',,,,,,,,,,,,,,,,,,,,,,,,,RT._tco', tail
      # what happens with an error here? 
      # if there is an error here it's *unhandled* -> apparently
      try 
        res = funcall.tail funcall.args...
        if res?.tail and res?.cb # this is an tailAsync result...
          return @_tcoAsync res, cb
        else if res?.tail 
          funcall = res 
        else if @isResult(res)
          if res instanceof Unit
            return cb null
          return cb null, @unbind res
        else
          return cb errorlet.create {error: 'invalid_tco_function_return', value: res}
      catch e 
        return cb e
    return tail.tail tail.args...
  tcoAsync: (func, args..., cb) ->
    self = @
    funcall.tail funcall.args..., (err, res) ->
      if err 
        cb err
      else
        
  _tcoAsync: (funcall, cb) ->
    self = @
    funcall.tail funcall.args..., (err, res) ->
  
  

module.exports = Runtime
