loglet = require 'loglet'
CodeBlock = require './codeblock'
Ref = require './ref'
baseEnv = require './baseenv'
Environment = require '../src/environment'
AST = require './ast'
errorlet = require 'errorlet'
Procedure = require './procedure'
ParameterList = require './parameter'
Opcode = require './opcode'

types = {}

register = (ast, compiler) ->
  #loglet.log 'compiler.register', ast.type
  if types.hasOwnProperty(ast.type)
    throw errorlet.create {error: 'duplicate_ast_type', ast: ast}
  else
    types[ast.type] = compiler

get = (ast) ->
  if types.hasOwnProperty(ast.type)
    types[ast.type]
  else
    throw errorlet.create {error: 'unknown_ast_type', ast: ast}

override = (ast, compiler) ->
  types[ast.type] = compiler

compile = (ast, env = baseEnv, code = new CodeBlock(), isTail = false) ->
  env = new Environment {}, env
  if ast instanceof Array # there ought not be such situation..???
    compile ast[0], env, code, isTail
  else
    compileOne ast, env, code, isTail

compileOne = (ast, env, code = new CodeBlock(), isTail = false) ->
  #loglet.log 'compileOne', ast
  if types.hasOwnProperty(ast.constructor.type)
    compiler = types[ast.constructor.type]
    compiler ast, env, code, isTail
  else
    throw errorlet.create {error: 'unsupported_ast_type', ast: ast}

compileScalar = (ast, env, code, isTail) ->
  code.push(ast.value)
  code

register AST.get('bool'), compileScalar

register AST.get('number'), compileScalar

register AST.get('string'), compileScalar

register AST.get('null'), compileScalar

compileBlock = (ast, env, code, isTail) ->
  for lineAST, i in ast.items
    if i == ast.items.length - 1
      # in a block - the last line will be the tail. but this should also only be in play if it's passed in.
      code.append compileOne(lineAST, env, new CodeBlock(), isTail) 
    else
      code.append compileOne(lineAST, env)
  code

register AST.get('block'), compileBlock

compileIf = (ast, env, code, isTail) ->
  condCode = compileOne astcond, env
  thenCode = compileOne ast.then, env, new CodeBlock(), isTail
  elseCode = compileOne ast.else, env, new CodeBlock(), isTail
  code.append(condCode)
    .ifOrJump(thenCode.length + 1)
    .append(thenCode)
    .jump(elseCode.length)
    .append(elseCode)

register AST.get('if'), compileIf

compileFuncall = (ast, env, code, isTail) ->
  for arg in ast.args 
    code.append compileOne arg, env
  code.append compileOne ast.funcall, env
  if isTail
    code.tailcall(ast.args.length)
  else
    code.funcall(ast.args.length)

register AST.get('funcall'), compileFuncall

compileIdentifier = (ast, env, code, isTail) ->
  if not env.has(ast.value)
    throw errorlet.create {error: 'compileIdentifier:unknown_identifier', id: ast.value}
  object = env.get ast.value
  if object instanceof Ref
    code.ref(object.name)
  else
    code.push object

register AST.get('symbol'), compileIdentifier

compileDefine = (ast, env, code, isTail) ->
  if env.has ast.name
    throw errorlet.crate {error: 'compileDefine:duplicate_definition', name: ast.name}
  valCode = compile ast.value, env
  code.append(valCode)
    .define(ast.name)

register AST.get('define'), compileDefine

compileParameter = (param, env, isTail) ->
  defaultCode = 
    if param.default
      compileOne param.default, env
    else
      null
  env.defineRef param.name
  ParameterList.makeParam param.name, param.type, defaultCode

compileParameters = (params, env, isTail) ->
  paramList = 
    for p in params
      compileParameter p, env
  ParameterList.make paramList

compileProcedure = (ast, env, code, isTail) ->
  # the truth of this is that we can just go ahead and make the environment!
  newEnv = new Environment {}, env
  params = compileParameters ast.params, newEnv
  proc = new Procedure ast.name, params, null
  if proc.name
    env.define proc.name, proc
  bodyAST = ast.body
  bodyCode = compileOne bodyAST, newEnv, new CodeBlock(), true
  proc.setBody bodyCode
  code.push proc # no reason to run through this again!

register AST.get('procedure'), compileProcedure

compileBinary = (ast, env, code, isTail) ->
  if not env.has ast.op
    throw {error: 'invalid_operator', name: ast.op}
  proc = env.get ast.op
  code.append compileOne ast.lhs, env
  code.append compileOne ast.rhs, env
  switch ast.op
    when '+'
      code.plus()
    when '-'
      code.minus()
    when '*'
      code.multiply()
    when '/'
      code.divide()
    when '%'
      code.modulo()
    when '>'
      code.greater()
    when '>='
      code.greaterEqual()
    when '<'
      code.less()
    when '<='
      code.lessEqual()
    when '=='
      code.equal()
    when '!='
      code.notEqual()
    else
      code.push proc
      if isTail
        code.tailcall 2
      else
        code.funcall 2  
  code
  
register AST.get('binary'), compileBinary

compileCatch = (ast, env, code, isTail) ->
  newEnv = new Environment {}, env
  param = compileParameter ast.param, newEnv
  # what does catch look like? 
  body = compileOne ast.body, newEnv
  code
    .ifErrorOrJump(body.length + 4)
    .pushEnv()
    .push(param)
    .bindErrorOrJump(body.length)
    .append(body)
    .popEnv()

_compileCatchClauses = (catches, env) ->
  helper = (ast) ->
    newEnv = new Environment {}, env
    param = compileParameter ast.param, env
    body = compileOne ast.body, newEnv
    new CodeBlock()
      .push(param)
      .bindErrorOrJump(body.length)
      .append(body)
  clauses = (helper(ast) for ast in catches)
  body = new CodeBlock()
  for clause in clauses
    body.append clause
  new CodeBlock()
    .ifErrorOrJump(body.length + 2)
    .pushEnv()
    .append(body)
    .popEnv()
  
register AST.get('catch'), compileCatch

compileThrow = (ast, env, code, isTail) ->
  body = compileOne ast.value, env
  code
    .append(body)
    .throw()

register AST.get('throw'), compileThrow

compileFinally = (ast, env, code, isTail) ->
  body = compileOne ast.body, env
  code
    .finally()
    .append(body)
    .endFinally()
  
register AST.get('finally'), compileFinally

# we also have an inner label as well - catch/try/finally isn't well self-contained!
# because the try block can take on previous label!
compileTry = (ast, env, code, isTail) ->
  body = compileOne ast.body, env
  catchLabel = Opcode.make 'label', 'catch'
  finallyLabel = Opcode.make 'label', 'finally'
  catchBody = _compileCatchClauses ast.catch, env, code
  finallyBody = 
    if ast.finally
      compileOne ast.finally, env
    else
      new CodeBlock().finally().endFinally()
  code
    .onThrowGoto(catchLabel)
    .append(body)
    .label(catchLabel)
    .onThrowGoto(finallyLabel)
    .append(catchBody)
    .label(finallyLabel)
    .append(finallyBody)
  
register AST.get('try'), compileTry

compileObject = (ast, env, code, isTail) ->
  helper = (valAST) ->
    compile valAST, env
  for [key, valAST] in ast.value
    code.push(key)
      .append(helper(valAST))
  code.object(ast.value.length * 2)

register AST.get('object'), compileObject

compileArray = (ast, env, code, isTail) ->
  for itemAST in ast.value
    code.append(compile(itemAST, env))
  code.array(ast.value.length)
  
register AST.get('array'), compileArray

compileMember = (ast, env, code, isTail) ->
  key = ast.key.value
  code
    .append(compileOne(ast.head, env))
    .member(key)

register AST.get('member'), compileMember

module.exports = 
  compile: compile
  register: register
  get: get
  override: override

