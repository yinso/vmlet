loglet = require 'loglet'
errorlet = require 'errorlet'

AST = require './ast'
LineBuffer = require './linebuffer'

types = {}

register = (ast, compiler) ->
  if types.hasOwnProperty(ast.type)
    throw errorlet.create {error: 'compiler:duplicate_compiler_type', type: ast.type}
  else
    types[ast.type] = compiler

get = (ast) ->
  if types.hasOwnProperty(ast.constructor.type)
    types[ast.constructor.type]
  else
    throw errorlet.create {error: 'compiler:unsupported_ast_type', type: ast.constructor.type}

override = (ast, compiler) ->
  types[ast.type] = compiler

compile = (anf) ->
  res = _compile anf
  """
  (function () {
    return #{res};
  })()
  """

_compile = (anf, buffer = new LineBuffer(), level = 0) ->
  _compileOne anf, buffer, level
  buffer.toString()
  
_compileOne = (ast, buffer, level) ->
  compiler = get ast
  compiler ast, buffer, level

compileBlock = (anf, buffer, level) ->
  for item, i in anf.items
    _compile anf.items[i], buffer, level
    buffer.push "; "
    buffer.newline()

register AST.get('block'), compileBlock

compileScalar = (ast, buffer, level) ->
  buffer.push JSON.stringify(ast.value)

register AST.get('number'), compileScalar
register AST.get('bool'), compileScalar
register AST.get('string'), compileScalar

compileNull = (ast, buffer, level) ->
  buffer.push "null"

register AST.get('null'), compileNull

compileSymbol = (ast, buffer, level) ->
  buffer.push ast.value

register AST.get('symbol'), compileSymbol

compileRef = (ast, buffer, level) ->
  buffer.push ast.normalized()

register AST.get('ref'), compileRef

compileBinary = (ast, buffer, level) ->
  #loglet.log 'compileBinary', ast
  lhs = _compile ast.lhs, new LineBuffer(), level
  rhs = _compile ast.rhs, new LineBuffer(), level
  buffer.push "(#{lhs} #{ast.op} #{rhs})"

register AST.get('binary'), compileBinary

compileLocal = (ast, buffer, level) ->
  if ast.init 
    value = _compile ast.normalized(), new LineBuffer(), level
    buffer.writeLine "var #{ast.name()} = #{value};"
  else
    buffer.writeLine "var #{ast.name()};"

register AST.get('local'), compileLocal

compileAssign = (ast, buffer, level) ->
  value = _compile ast.value, new LineBuffer(), level
  buffer.writeLine "#{ast.name} = #{value};"

register AST.get('assign'), compileAssign


compileDefine = (ast, buffer, level) ->
  value = _compile ast.value, new LineBuffer(), level
  buffer.writeLine "_rt.define(#{JSON.stringify(ast.name)}, #{value});"

register AST.get('define'), compileDefine

#compileTempVar = (ast, buffer, level) ->
#  value = _compile ast.value, new LineBuffer(), level
#  buffer.writeLine "var #{ast.name} = #{value};"
#
#register AST.get('tempvar'), compileTempVar

compileParam = (ast, buffer, level) ->
  buffer.push ast.name

register AST.get('param'), compileParam

compileProcedure = (ast, buffer, level) ->
  loglet.log 'compileProcedure', ast, level
  body = _compile ast.body, new LineBuffer(), level + 1
  params = (_compile(param) for param in ast.params).join(', ')
  buffer.push "function "
  if ast.name 
    if ast.name instanceof AST and ast.name.type() == 'ref'
      buffer.push ast.name.name
    else
      buffer.push ast.name
  buffer.push "(#{params}) { "
  buffer.push "#{body} }"

register AST.get('procedure'), compileProcedure

compileFuncall = (ast, buffer, level) ->
  _compileOne ast.funcall, buffer, level
  args = 
    for arg in ast.args
      _compile arg, new LineBuffer(), level
  buffer.push "(#{args.join(', ')})"

register AST.get('funcall'), compileFuncall  

compileMember = (ast, buffer, level) ->
  buffer.push "_rt.member("
  _compileOne ast.head, buffer, level
  buffer.push ", "
  if ast.key.type() == 'symbol'
    buffer.push JSON.stringify(ast.key.value)
  else
    key = _compile ast.key, new LineBuffer(), level
    buffer.push key
  buffer.push ")"

register AST.get('member'), compileMember

compileObject = (ast, buffer, level) ->
  # all the inner of the object should be ANF'd here so we are left with literals and symbols.
  buffer.push '{'
  for [ key , val ], i in ast.value
    buffer.push JSON.stringify(key)
    buffer.push ': '
    _compileOne val, buffer, level
    if i < ast.value.length - 1
      buffer.push ', '
  buffer.push '}'

register AST.get('object'), compileObject

compileArray = (ast, buffer, level) ->
  buffer.push '['
  for item, i in ast.value 
    _compileOne item, buffer, level
    if i < ast.value.length - 1
      buffer.push ', '
  buffer.push ']'

register AST.get('array'), compileArray

compileProxyVal = (ast, buffer, level) ->
  buffer.push ast.compile()

register AST.get('proxyval'), compileProxyVal

compileReturn = (ast, buffer, level) ->
  val = ast.value
  type = val.type()
  buffer.push "return "
  _compile val, buffer, level
  buffer.push ";"

register AST.get('return'), compileReturn 

compileThrow = (ast, buffer, level) ->
  buffer.push "throw "
  _compile ast.value, buffer
  buffer.writeLine ";"

register AST.get('throw'), compileThrow

compileTry = (ast, buffer, level) ->
  buffer.push "try { "
  _compile ast.body, buffer, level + 1 
  buffer.push " } "
  for c in ast.catches
    _compile c, buffer, level 
  _compile ast.finally, buffer, level

register AST.get('try'), compileTry

compileCatch = (ast, buffer, level) ->
  buffer.push "catch ("
  _compile ast.param, buffer, level
  buffer.push ") { "
  _compile ast.body, buffer, level + 1
  buffer.push "} "

register AST.get('catch'), compileCatch

compileFinally = (ast, buffer, level) ->
  buffer.push "finally { "
  _compile ast.body, buffer, level + 1
  buffer.push "} "

register AST.get('finally'), compileFinally

compileIf = (ast, buffer, level) ->
  loglet.log '--compileIf', ast
  condE = _compile ast.cond, new LineBuffer(), level
  thenE = _compile ast.then, new LineBuffer(), level
  elseE = _compile ast.else, new LineBuffer(), level
  buffer.write "if (#{condE}) {"
  buffer.newline()
  buffer.indent()
  buffer.write thenE
  buffer.outdent()
  buffer.write "} else {"
  buffer.indent()
  buffer.write elseE
  buffer.outdent()
  buffer.write "}"

register AST.get('if'), compileIf

module.exports = 
  compile: compile
  get: get
  register: register
  override: override


###
# tail recursive version
(function (n) { (function helper(n, cur, next) { if n <= 0 cur else helper(n - 1, next, cur + next) })(n, 0, 1) })(5)
define fib = function(n) { define helper = function helper(n, cur, next) { if n <= 0 cur else helper(n - 1, next, cur + next)} helper(n, 0, 1) }
  

###





  
  