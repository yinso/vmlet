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
UNIQ = require './unique'

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

class Module 
  constructor: (@prevEnv = null) ->
    @inner = {}
    @imports = {}
    @exports = {}
    @depends = [] # list of modules that this module depends on...
    @env = new SymbolTable(@prevEnv)
  define: (key, val) ->
    @inner[key] = val
    #@env.define AST.symbol(key), val # the value needs to be just a ref I think...
    val
  export: (key, as = key) ->
  import: (keys = []) ->
    if keys.length > 0 
      res = []
      for key in keys 
        res[key] = @get key
      res
    else
      @exports
  has: (key) ->
    @inner.hasOwnProperty(key)
  get: (key) ->
    if not @has key
      throw new Error("Module.unknown_identifier: #{key}")
    @inner[key]
  
class Toplevel 
  constructor: (@proc, @module) ->
  eval: (cb) ->
    try 
      @proc @module, cb
    catch e 
      cb e

# we want something that signifies the global module and that's the baseEnv...
# when we define a module we not only want to define 
class Runtime
  constructor: (@baseEnv = new SymbolTable(), @main = new Module(@baseEnv)) ->
    @parser = parser
    @AST = AST
    # now the biggest challenge starts!
    @baseEnv.define AST.symbol('fs'),
      readFile: @makeAsync (_rt) ->
        readFile = _rt.member(fs, 'readFile')
        (args...) ->
          return readFile args...
    @baseEnv.define AST.symbol('console'), AST.proxyval('console', AST.symbol('console'))
    @baseEnv.define AST.symbol('import'), AST.proxyval('import', AST.member(AST.symbol('_rt'), AST.symbol('import')))
    @context = vm.createContext { _rt: @ , console: console , process: process }
  unit: Unit.unit
  proc: (func, def) -> 
    Object.defineProperty func, '__vmlet',
      value: 
        sync: true
        def: def 
    func
  task: (func, def) ->
    Object.defineProperty func, '__vmlet',
      value: 
        sync: false
        def: def 
    func
  member: (head, key) ->
    res = head[key]
    if util.isFunction(res)
      (args...) ->
        res.apply head, args
    else
      res
  toplevel: (proc, module) ->
    new Toplevel proc, module
  module: (proc) ->
    module = proc()
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
    node = ast.toESNode()
    compiled = '(' + escodegen.generate(node)  + ')'
    loglet.log '-------- Runtime.compiled =>', compiled
    vm.runInContext compiled, @context
  parse: (stmt) ->
    ast = @parser.parse stmt
    loglet.log '-------- Runtime.parsed =>', ast
    ast
  import: (filePath, cb) ->
    # we will deal with external package path once things are loaded... 
    if @isPackage filePath 
      # there are a few things to deal with here... 
      # 1 - things about loading the actual underlying node modules... 
      try 
        module = require filePath 
        
      catch e 
        cb e 
    else
      try 
        fs.readFile filePath, 'utf8', (err, data) =>
          if err 
            cb err 
          else
            try # this isn't really trying to 
              parsed = AST.module @parse data 
              ast = @transform ast 
              compiled = @compile ast 
              compiled.eval cb
            catch e 
              cb e
      catch e 
         cb e
  isPackage: (filePath) -> 
    false
  eval: (stmt, cb) ->
    if stmt == ':context'
      return cb null, @context
    else if stmt == ':env'
      return cb null, @baseEnv
    try 
      ast = AST.toplevel @parse stmt 
      ast = @transform ast
      compiled = @compile ast
      try 
        compiled.eval (err, res) =>
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
  extractImports: (ast) ->
    # imports should be @ at the top level expressions...
    switch ast.type()
      when 'toplevel', 'module'
        @extractImports ast.body
      when 'block'
        results = []
        for item in ast.items 
          if item.type() == 'import'
            results.push item 
        results
      when 'import'
        [ ast ]
      else
        throw new Error("runtime.imports.invalid_expression: #{ast}")
  transform: (ast, module = @main) ->
    ast = RESOLVER.transform ast, module.env
    loglet.log '-------- Runtime.transformed =>', ast, module.env
    ast = CPS.transform ast
    loglet.log '-------- Runtime.cpsed =>', ast
    ast
  get: (key) ->
    @baseEnv.get key
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
