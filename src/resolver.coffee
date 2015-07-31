# resolver is to resolve the dangling symbols/identifiers to make sure that they are properly assigned.
# this would look very similar to ANF transformation in many ways...
AST = require './ast'
Environment = require './environment'
TR = require './trace'
FreeVariable = require './freevariable'

class Resolver 
  @transform: (ast, env = new Environment()) -> 
    if not @reg
      @reg = new @()
    @reg.transform ast, env
  transform: (ast, env = new Environment()) -> 
    switch ast.type()
      when 'toplevel', 'module'
        resolved = @run ast.body, env 
        ast.clone resolved 
      else
        @run ast, env
  run: (ast, env) -> 
    type = "_#{ast.type()}"
    if @[type]
      @[type] ast, env 
    else
      throw new Error("Resolver.unknown_ast: #{ast.type()}")
  _number: (ast, env) -> ast 
  _string: (ast, env) -> ast 
  _bool: (ast, env) -> ast 
  _null: (ast, env) -> ast 
  _unit: (ast, env) -> ast 
  _ref: (ast, env) -> ast # this should not have occured at this level...???
    #env.get ast.name
  _binary: (ast, env) -> 
    lhs = @run ast.lhs, env
    rhs = @run ast.rhs, env 
    AST.binary ast.op, lhs, rhs 
  _if: (ast, env) -> 
    cond = @run ast.cond, env 
    thenAST = @run ast.then, env 
    elseAST = @run ast.else, env 
    AST.if cond, thenAST, elseAST 
  _block: (ast, env) ->
    # block doesn't introduce new scoping... 
    # maybe that's better... hmm...
    # function and let introduce new scoping.
    #newEnv = new Environment env
    # first pull out all of the defines. 
    for item, i in ast.items 
      if item.type() == 'define'
        @defineName item, env
    items = 
      for item, i in ast.items
        if item.type() == 'define'
          @defineVal item, env
        else
          @run item, env
    AST.block items
  _toplevel: (ast, env) ->
    AST.toplevel @run(ast.body, env)
  defineName: (ast, env) -> 
    if env.hasCurrent ast.name 
      throw new Error("duplicate_define: #{ast.name}")
    ref = env.define ast.name 
    if env.level() <= 1 
      ref.isDefine = true 
  defineVal: (ast, env) ->
    # at this time we assume define exists... 
    ref = env.get ast.name 
    res = @run ast.value, env 
    ref.value = res 
    ref.define()
  _define: (ast, env) ->
    @defineName ast, env
    @defineVal ast, env
  assign: (ast, env) -> 
    ref = @run ast.name, env 
    val = @run ast.value, env 
    AST.assign ref, val 
  _symbol: (ast, env) ->
    if env.hasName ast
      env.get ast
    else
      throw new Error("Resolver.unknown_identifier: #{ast}")
  _object: (ast, env) ->
    keyVals = 
      for [key, val] in ast.value
        v = @run val, env
        [key, v]
    AST.object keyVals
  _array: (ast, env) ->
    items = 
      for v in ast.value
        @run v, env
    AST.array items
  _member: (ast, env) ->
    head = @run ast.head, env
    AST.member head, ast.key
  @makeProcCall: (type) -> 
    (ast, env) -> 
      args = 
        for arg in ast.args
          @run arg, env
      # console.log '-- transform.funcall', ast.funcall, env
      funcall = @run ast.funcall, env
      AST.make type, funcall, args
  _funcall: @makeProcCall('funcall')
  _taskcall: @makeProcCall('taskcall')
  _param: (ast, env) ->
    # what is the define param...??? 
    ref = env.define ast.name, ast
    ast.name = ref 
    ast
  @makeProc: (type) ->
    (ast, env) ->
      newEnv = new Environment env
      params = 
        for param in ast.params
          @run param, newEnv
          #newEnv.defineParam param
      decl = AST.make type, ast.name, params, null 
      if ast.name 
        if env.has(ast.name) and env.get(ast.name).isPlaceholder()
          ref = env.get(ast.name)
          ref.value = decl
          decl.name = ref
        else # it's not defined at a higher level, we need to create our own definition.
          ref = newEnv.define ast.name , decl 
          decl.name = ref
      decl.body = @run ast.body, newEnv
      decl.frees = FreeVariable.transform decl, newEnv
      decl
  _procedure: @makeProc('procedure')
  _task: @makeProc('task')
  _throw: (ast, env) ->
    exp = @run ast.value, env
    AST.throw exp
  _catch: (ast, env) ->
    newEnv = new Environment env
    ref = newEnv.defineParam ast.param
    body = @run ast.body, newEnv
    AST.catch ast.param, body
  _finally: (ast, env) ->
    body = _transform ast.body, env
    AST.finally body
  _try: (ast, env) ->
    newEnv = new Environment env
    body = @run ast.body, newEnv
    catches = 
      for c in ast.catches
        @_catch c, env
    fin = 
      if ast.finally instanceof AST
        @_finally ast.finally, env
      else
        null
    AST.try body, catches, fin
  _import: (ast, env) ->
    # when we are transforming import, we are introducing bindings.
    for binding in ast.bindings 
      res = env.define binding.as, ast.proxy(binding)
      #TR.log '--import.binding', res, res.value
    ast
  _export: (ast, env) ->
    bindings = 
      for binding in ast.bindings 
        if not env.has binding.spec 
          throw new Error("export:unknown_identifier: #{binding.binding}")
        else
          AST.binding(env.get(binding.spec), binding.as)
    AST.export(bindings)
  _let: (ast, env) ->
    newEnv = new Environment env
    defines = 
      for define in ast.defines 
        @run define , newEnv
    body = @run ast.body , newEnv 
    AST.let defines, body
  _while: (ast, env) -> 
    cond = @run ast.cond, env 
    block = @run at.blcok, env 
    AST.while cond, block 
  _return: (ast, env) -> 
    AST.return @run ast.value, env
  _continue: (ast, env) -> ast
  _break: (ast, env) -> ast 
  
    
  
module.exports = Resolver


