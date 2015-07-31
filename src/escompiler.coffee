escodegen = require 'escodegen'
AST = require './ast'
Environment = require './symboltable'

class ESCompiler
  @compile: (ast) -> 
    if not @reg 
      @reg = new @()
    @reg.compile ast 
  compile: (ast) -> 
    node = @run ast, Environment.make({newSym: true})
    '(' + escodegen.generate(node)  + ')'
  run: (ast, env, res) -> 
    type = "_#{ast.type()}"
    if @[type]
      @[type] ast, env, res 
    else
      throw new Error("ESCompiler.unknown_ast: #{ast.type()}")
  identifier: (name) ->
    if name == null or name == undefined
      name
    else
      type: 'Identifier'
      name: name
  literal: (val) ->
    if val == undefined
      @undefined_()
    else
      type: 'Literal'
      value: val
  null_: () ->
    @literal null
  undefined_: () ->
    @identifier 'undefined'
  member: (obj, key) ->
    type: 'MemberExpression'
    computed: false
    object: obj
    property: key
  funcall: (proc, args) ->
    type: 'CallExpression'
    callee: proc
    arguments: args
  object: (keyvals) ->
    propHelper = (key, val) =>
      type: 'Property'
      computed: false
      key: @identifier(key)
      value: val
      kind: 'init'
      method: false
      shorthand: false
    type: 'ObjectExpression'
    properties: 
      for [key, val] in keyvals
        propHelper key, val
  array: (items) ->
    type: 'ArrayExpression'
    elements: items
  if: (cond, thenExp, elseExp) ->
    type: 'IfStatement'
    test: cond
    consequent: thenExp
    alternate: elseExp
  block: (stmts) ->
    type: 'BlockStatement'
    body: stmts
  declare: (type, nameVals...) ->
    helper = (name, val) ->
      type: 'VariableDeclarator'
      id: name
      init: val
    type: 'VariableDeclaration'
    kind: type
    declarations: 
      for [name, val] in nameVals
        helper name, val
  assign: (name, val) ->
    type: 'AssignmentExpression'
    operator: '='
    left: name
    right: val
  function: (name, params, body) ->
    type: 'FunctionExpression'
    id: name
    params: params
    defaults: []
    body: body
    generator: false
    expression: false
  return: (value) ->
    type: 'ReturnStatement'
    argument: value
  unary: (op, val) ->
    type: 'UnaryExpression'
    operator: op 
    argument: val 
    prefix: true
  binary: (op, lhs, rhs) ->
    type: 'BinaryExpression'
    operator: op
    left: lhs
    right: rhs
  throw: (val) ->
    type: 'ThrowStatement'
    argument: val
  catch: (param, body) ->
    type: 'CatchClause'
    param: param 
    body: body
  try: (block, catchHandlers, finalHandler = null) ->
    res = 
      type: 'TryStatement'
      block: block
      handlers: catchHandlers
      handler: if catchHandlers.length > 0 then catchHandlers[0] else null
      finalizer: finalHandler
  while: (cond, block) ->
    type: 'WhileStatement'
    test: cond
    body: block
  switch: (cond, cases) ->
    type: 'SwitchStatement'
    discriminant: cond
    cases: cases
  case: (cond, exp) ->
    type: 'SwitchCase'
    test: cond
    consequent: exp
  defaultCase: (exp) ->
    @case null, exp
  continue: (label = null) -> 
    type: 'ContinueStatement'
    label: label

  break: (label = null) ->
    type: 'BreakStatement'
    label: label

  label: (label, body) ->
    type: 'LabeledStatement'
    label: label
    body: body

  expression: (exp) ->
    type: 'ExpressionStatement'
    expression: exp

  program: (body = []) ->
    type: 'Program'
    body: body
  
  _number: (ast, env) -> 
    if ast.value < 0 
      @unary '-', @literal -ast.value
    else
      @literal ast.value
  _string: (ast, env) -> 
    @literal ast.value 
  _bool: (ast, env) -> 
    @literal ast.value 
  _null: (ast, env) ->
    @null_()
  _unit: (ast, env) ->
    @undefined_()
  _member: (ast, env) ->
    head = @run ast.head, env
    key = 
      if ast.key.type() == 'symbol'
        @literal(ast.key.value)
      else
        @run ast.key, env
    runtimeID = @run(AST.runtimeID, env)
    @funcall @member(runtimeID, @identifier('member')), [ head , key ]
  _symbol: (ast, env) ->
    ref = env.alias ast
    @identifier ref.name.value
  _object: (ast, env) ->
    @object ([key, @run(val, env)] for [key, val] in ast.value)
  _array: (ast, env) ->
    @array (@run(item, env) for item in ast.value)
  _block: (ast, env) ->
    @block (@run(item, env) for item in ast.items)
  _assign: (ast, env) ->
    @assign @run(ast.name, env), @run(ast.value, env)
  _define: (ast, env) ->
    name = 
      switch ast.name.type()
        when 'ref'
          @literal ast.name.name.value
        when 'symbol'
          @literal ast.name.value
        else
          throw new Error("escompile.define:unknown_name_type: #{ast.name}")
    value = 
      @funcall @member(@run(AST.moduleID, env), @identifier('define')),
        [ name , @run(ast.value, env.pushEnv()) ]
    id = 
      switch ast.name.type()
        when 'ref'
          @run(ast.name.normalName(), env)
        when 'symbol'
          @run(ast.name, env)
        else
          throw new Error("escompile.define:unknown_name_type: #{ast.name}")
    @declare 'var', [ id, value ]
  _local: (ast, env) ->
    name = @run(ast.name, env) 
    if not ast.value
      @declare 'var', [ name ]
    else
      @declare 'var', [ name , @run(ast.value, env) ]
  _ref: (ast, env) ->
    #if not ast.value 
    #  throw new Error("escompile.ref.no_value: #{ast}")
    #console.log 'ESCompile.ref', ast, ast.isDefine, ast.value
    if ast.value?.type() == 'proxyval'
      @run ast.value, env
    else if ast.isDefine
      @funcall @member(@run(AST.moduleID, env), @identifier('get')), 
        [ @literal(ast.name.value) ]
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
    func = @function name, (@run(param, env) for param in ast.params), @run(ast.body, env)
    maker = @member(@run(AST.runtimeID, env), @identifier('proc'))
    @funcall maker, [ func ]
  _task: (ast, env) ->
    name = if ast.name then @run(ast.name, env) else null
    @function name, (@run(param, env) for param in ast.params), @run(ast.body, env)
  _if: (ast, env) ->
    @if @run(ast.cond, env), @run(ast.then, env), @run(ast.else, env)
  _funcall: (ast, env) ->
    @funcall @run(ast.funcall, env), (@run(arg, env) for arg in ast.args)
  _taskcall: (ast, env) -> 
    @funcall @run(ast.funcall, env), (@run(arg, env) for arg in ast.args)
  _return: (ast, env) ->
    @return @run(ast.value, env) 
  _binary: (ast, env) ->
    @binary ast.op, @run(ast.lhs, env), @run(ast.rhs, env)
  _throw: (ast, env) ->
    @throw @run(ast.value, env)
  _catch: (ast, env) ->
    @catch @run(ast.param, env), @run(ast.body, env)
  _finally: (ast, env) ->
    @run ast, env
  _try: (ast, env) ->
    @try @run(ast.body, env), (@_catch(exp, env) for exp in ast.catches), if ast.finally then @_finally(ast.finally, env) else null
  _toplevel: (ast, env) ->
    _rt = @run(AST.runtimeID, env)
    imports = @array(@_importSpec(imp, env) for imp in ast.imports)
    params = 
      [ @run(ast.moduleParam, env) ].concat(@_importID(imp, env) for imp in ast.imports).concat([ @run(ast.callbackParam, env) ])
    proc = @function null, params, @run(ast.body, env)
    @funcall @member(_rt, @identifier('toplevel')),
      [ 
        imports 
        proc 
      ]
  _module: (ast, env) ->
    _rt = @run(AST.runtimeID, env)
    imports = @array(@_importSpec(imp, env) for imp in ast.imports)
    params = 
      [ @run(ast.moduleParam, env) ].concat(@_importID(imp, env) for imp in ast.imports).concat([ @run(ast.callbackParam, env) ])
    proc = @function null, params, @run(ast.body, env)
    @funcall @member(_rt, @identifier('module')),
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
    [ @run(binding.as, env) , @member(@_importID(ast, env), @run(binding.spec, env)) ]
  
  _import: (ast, env) ->
    @declare 'var', (@_importBidning(ast, binding, env) for binding in ast.bindings)...
  _export: (ast, env) ->
    @funcall @member(@run(AST.moduleID, env), @identifier('export')), 
      [ 
        @object ([binding.as.value, @run(binding.spec, env)] for binding in ast.bindings)
      ]
  _while: (ast, env) -> 
    @while @run(ast.cond, env), @run(ast.block, env)
  _switch: (ast, env) -> 
    @switch @run(ast.cond, env), (@run(c, env) for c in ast.cases)
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
    @case @run(ast.cond, env), body
  _defaultCase: (ast, env) -> 
    @defaultCase @run(ast.exp, env)
  _continue: (ast, env) -> 
    @continue()
  _break: (ast, env) ->
    @break()
  
module.exports = ESCompiler

