escodegen = require 'escodegen'
esnode = require './esnode'
AST = require './ast'
TR = require './trace'
Environment = require './symboltable'

class ESCompiler
  @compile: (ast) -> 
    if not @reg 
      @reg = new @()
    @reg.compile ast 
  compile: (ast) -> 
    node = @run ast, new Environment()
    '(' + escodegen.generate(node)  + ')'
  run: (ast, env, res) -> 
    type = "_#{ast.type()}"
    if @[type]
      @[type] ast, env, res 
    else
      throw new Error("ESCompiler.unknown_ast: #{ast.type()}")
  _number: (ast, env) -> 
    if ast.value < 0 
      esnode.unary '-', esnode.literal -ast.value
    else
      esnode.literal ast.value
  _string: (ast, env) -> 
    esnode.literal ast.value 
  _bool: (ast, env) -> 
    esnode.literal ast.value 
  _null: (ast, env) ->
    esnode.null_()
  _unit: (ast, env) ->
    esnode.undefined_()
  _member: (ast, env) ->
    head = @run ast.head, env
    key = 
      if ast.key.type() == 'symbol'
        esnode.literal(ast.key.value)
      else
        @run ast.key, env
    runtimeID = @run(AST.runtimeID, env)
    esnode.funcall esnode.member(runtimeID, esnode.identifier('member')), [ head , key ]
  _symbol: (ast, env) ->
    sym = env.alias ast
    esnode.identifier sym.value
  _object: (ast, env) ->
    esnode.object ([key, @run(val, env)] for [key, val] in ast.value)
  _array: (ast, env) ->
    esnode.array (@run(item, env) for item in ast.value)
  _block: (ast, env) ->
    esnode.block (@run(item, env) for item in ast.items)
  _assign: (ast, env) ->
    esnode.assign @run(ast.name, env), @run(ast.value, env)
  _define: (ast, env) ->
    name = 
      switch ast.name.type()
        when 'ref'
          esnode.literal ast.name.name.value
        when 'symbol'
          esnode.literal ast.name.value
        else
          throw new Error("escompile.define:unknown_name_type: #{ast.name}")
    value = 
      esnode.funcall esnode.member(@run(AST.moduleID, env), esnode.identifier('define')),
        [ name , @run(ast.value, new Environment(env)) ]
    id = 
      switch ast.name.type()
        when 'ref'
          @run(ast.name.normalName(), env)
        when 'symbol'
          @run(ast.name, env)
        else
          throw new Error("escompile.define:unknown_name_type: #{ast.name}")
    esnode.declare 'var', [ id, value ]
  _local: (ast, env) ->
    name = @run(ast.name, env) 
    if not ast.value
      esnode.declare 'var', [ name ]
    else
      esnode.declare 'var', [ name , @run(ast.value, env) ]
  _ref: (ast, env) ->
    #if not ast.value 
    #  throw new Error("escompile.ref.no_value: #{ast}")
    #console.log 'ESCompile.ref', ast, ast.isDefine, ast.value
    if ast.value?.type() == 'proxyval'
      @run ast.value, env
    else if ast.isDefine
      esnode.funcall esnode.member(@run(AST.moduleID, env), esnode.identifier('get')), 
        [ esnode.literal(ast.name.value) ]
    else
      @run ast.name, env
  _proxyval: (ast, env) ->
    res = 
      if typeof(ast.compiler) == 'function' or ast.compiler instanceof Function 
        ast.compiler(env)
      else if ast.compiler instanceof AST
        @run ast.compiler, env
      else
        @run ast.name, env
    res
  _param: (ast, env) ->
    @run ast.name, env
  _procedure: (ast, env) ->
    name = if ast.name then @run(ast.name, env) else null
    func = esnode.function name, (@run(param, env) for param in ast.params), @run(ast.body, env)
    maker = esnode.member(@run(AST.runtimeID, env), esnode.identifier('proc'))
    esnode.funcall maker, [ func ]
  _task: (ast, env) ->
    name = if ast.name then @run(ast.name, env) else null
    esnode.function name, (@run(param, env) for param in ast.params), @run(ast.body, env)
  _if: (ast, env) ->
    esnode.if @run(ast.cond, env), @run(ast.then, env), @run(ast.else, env)
  _funcall: (ast, env) ->
    esnode.funcall @run(ast.funcall, env), (@run(arg, env) for arg in ast.args)
  _taskcall: (ast, env) -> 
    esnode.funcall @run(ast.funcall, env), (@run(arg, env) for arg in ast.args)
  _return: (ast, env) ->
    esnode.return @run(ast.value, env) 
  _binary: (ast, env) ->
    esnode.binary ast.op, @run(ast.lhs, env), @run(ast.rhs, env)
  _throw: (ast, env) ->
    esnode.throw @run(ast.value, env)
  _catch: (ast, env) ->
    esnode.catch @run(ast.param, env), @run(ast.body, env)
  _finally: (ast, env) ->
    @run ast, env
  _try: (ast, env) ->
    esnode.try @run(ast.body, env), (@_catch(exp, env) for exp in ast.catches), if ast.finally then @_finally(ast.finally, env) else null
  _toplevel: (ast, env) ->
    _rt = @run(AST.runtimeID, env)
    imports = esnode.array(@_importSpec(imp, env) for imp in ast.imports)
    params = 
      [ @run(ast.moduleParam, env) ].concat(@_importID(imp, env) for imp in ast.imports).concat([ @run(ast.callbackParam, env) ])
    proc = esnode.function null, params, @run(ast.body, env)
    esnode.funcall esnode.member(_rt, esnode.identifier('toplevel')),
      [ 
        imports 
        proc 
      ]
  _module: (ast, env) ->
    _rt = @run(AST.runtimeID, env)
    imports = esnode.array(@_importSpec(imp, env) for imp in ast.imports)
    params = 
      [ @run(ast.moduleParam, env) ].concat(@_importID(imp, env) for imp in ast.imports).concat([ @run(ast.callbackParam, env) ])
    proc = esnode.function null, params, @run(ast.body, env)
    esnode.funcall esnode.member(_rt, esnode.identifier('module')),
      [
        @run(ast.spec, env)
        imports
        proc
      ]
  _importSpec: (ast, env) ->
    @run ast.spec, env

  _importID: (ast, env) ->
    @run ast.idParam, env

  _importBinding: (ast, binding, env) ->
    [ @run(binding.as, env) , esnode.member(@_importID(ast, env), @run(binding.spec, env)) ]
  
  _import: (ast, env) ->
    esnode.declare 'var', (@_importBidning(ast, binding, env) for binding in ast.bindings)...
  _export: (ast, env) ->
    esnode.funcall esnode.member(@run(AST.moduleID, env), esnode.identifier('export')), 
      [ 
        esnode.object ([binding.as.value, @run(binding.spec, env)] for binding in ast.bindings)
      ]
  _while: (ast, env) -> 
    esnode.while @run(ast.cond, env), @run(ast.block, env)
  _switch: (ast, env) -> 
    esnode.switch @run(ast.cond, env), (@run(c, env) for c in ast.cases)
  _case: (ast, env) -> 
    body = 
      switch ast.exp.type()
        when 'block'
          for item, i in ast.exp.items
            @run(item, env)
        else
          [
            @run(item, env)
          ]
    esnode.case @run(ast.cond, env), body
  _defaultCase: (ast, env) -> 
    esnode.defaultCase @run(ast.exp, env)
  _continue: (ast, env) -> 
    esnode.continue()
  _break: (ast, env) ->
    esnode.break()
  
module.exports = ESCompiler

