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
async = require 'async'

esnode = require './esnode'
escodegen = require 'escodegen'

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
  @fromPrev: (name, prevEnv) ->
    new @ name, new SymbolTable prevEnv
  constructor: (@name , @env = new SymbolTable()) ->
    @inner = {}
    @imports = {}
    @exports = {}
    @depends = [] # list of modules that this module depends on...
  idName: () ->
    if @name == ':main'
      AST.symbol '_module'
    else
      AST.symbol @name.replace /[\.\\\/]/g, '_'
  define: (key, val) ->
    @inner[key] = val
    val
  export: (key, as = null) ->
    if not as 
      as = key
    @exports[as] = @get(key)
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
  constructor: (@depends, @proc, @module) ->
    console.log 'Toplevel.ctor', @module.name
  eval: (cb) ->
    args = [ @module ].concat(@depends).concat [cb]
    try 
      @proc.apply @, args
    catch e 
      cb e

# we want something that signifies the global module and that's the baseEnv...
# when we define a module we not only want to define 
class Runtime
  constructor: (@baseEnv = new SymbolTable(), @main = Module.fromPrev(':main', @baseEnv)) ->
    @modules = {}
    @envs = {}
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
  toplevel: (depends, proc, module = @main) ->
    modules = 
      for dep in depends 
        if not @modules.hasOwnProperty(dep)
          throw new Error("runtime:unknown_module: #{spec}")
        @modules[dep]
    new Toplevel modules, proc, module
  module: (id , depends, proc) ->
    if not @envs.hasOwnProperty(id)
      throw new Error("runtime:invalid_module_env: #{spec}")
    @toplevel depends, proc, new Module(id , @envs[id])
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
  parse: (stmt) ->
    ast = @parser.parse stmt
    #loglet.log '-------- Runtime.parsed =>', ast
    ast
  transform: (ast, env = @main.env) ->
    ast = RESOLVER.transform ast, env
    #loglet.log '-------- Runtime.transformed =>', ast, module.env
    #ast = CPS.transform ast
    ast
  compile: (ast) ->
    node = ast.toESNode()
    compiled = '(' + escodegen.generate(node)  + ')'
    loglet.log '-------- Runtime.compiled =>', compiled
    vm.runInContext compiled, @context
  isPackage: (filePath) -> 
    false
  eval: (stmt, cb) ->
    if stmt.indexOf(':modules') == 0
      return cb null, util.stringify(@modules)
    else if stmt.indexOf(':env') == 0
      return cb null, util.stringify(@main)
    try 
      ast = AST.toplevel @parse stmt 
      @evalParsed ast, @main.env, cb
    catch e
      cb e
  evalParsed: (ast, env, cb) ->
    @loadImports ast, (err) =>
      #console.log '--evalParsed.after.import', ast, err
      if err 
        cb err 
      else
        try 
          ast = @transform ast, env
          compiled = @compile ast
          compiled.eval (err, res) ->
            #console.log '--evalParsed.compiled.result', err, res
            if err 
              cb err
            else if res instanceof Unit
              cb null
            else
              cb err, res
        catch e
          cb e
  loadImports: (ast, cb) ->
    try 
      async.eachSeries ast.importSpecs(), (spec, next) => 
        @loadImport spec, next 
      , cb
    catch e 
      cb e
  loadImport: (spec, cb) ->
    #console.log '-- runtime.loadImport', spec
    try 
      fs.readFile spec, 'utf8', (err, data) =>
        if err 
          cb err 
        else
          try # this isn't really trying to 
            parsed = AST.module AST.string(spec), @parse data 
            @envs[spec] = new SymbolTable @baseEnv
            @evalParsed parsed, @envs[spec], (err, module) =>
              if err 
                cb err
              else
                @modules[spec] = module 
                cb null
          catch e 
            cb e
    catch e 
      cb e

module.exports = Runtime
