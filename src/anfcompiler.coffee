loglet = require 'loglet'
errorlet = require 'errorlet'

AST = require './ast'
ANF = require './anf'
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
  (function (_done) {
    try {
      #{res}
    } catch (e) {
      return _done(e);
    }
  })(_done)
  """

_compile = (anf, buffer = new LineBuffer(), level = 0) ->
  if (ANF.isANF(anf))
    _compileANF anf, buffer, level
  else
    _compileOne anf, buffer, level
  buffer.toString()
  
_compileANF = (anf, buffer, level) ->
  for item, i in anf.items
    _compile anf.items[i], buffer, level

_compileOne = (ast, buffer, level) ->
  #loglet.log '_complieOne', ast, level
  compiler = get ast
  compiler ast, buffer, level

compileScalar = (ast, buffer, level) ->
  buffer.push JSON.stringify(ast.val)

register AST.get('number'), compileScalar
register AST.get('bool'), compileScalar
register AST.get('null'), compileScalar
register AST.get('string'), compileScalar

compileSymbol = (ast, buffer, level) ->
  buffer.push ast.val

register AST.get('symbol'), compileSymbol

compileRef = (ast, buffer, level) ->
  buffer.push ast.val

register AST.get('ref'), compileRef

compileBinary = (ast, buffer, level) ->
  #loglet.log 'compileBinary', ast
  lhs = _compile ast.lhs, new LineBuffer(), level
  rhs = _compile ast.rhs, new LineBuffer(), level
  buffer.push "#{lhs} #{ast.op} #{rhs}"

register AST.get('binary'), compileBinary

compileDefine = (ast, buffer, level) ->
  value = _compile ast.val, new LineBuffer(), level
  buffer.push "var #{ast.name} = #{value};"

register AST.get('define'), compileDefine

compileParam = (ast, buffer, level) ->
  buffer.push ast.name

register AST.get('param'), compileParam

compileProcedure = (ast, buffer, level) ->
  loglet.log 'compileProcedure', ast, level
  body = _compile ast.body, new LineBuffer(), level + 1
  params = (_compile(param) for param in ast.params).join(', ')
  buffer.push "function "
  if ast.name
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
  _compileOne ast.head, buffer, level
  key = _compile ast.key, new LineBuffer(), level
  if AST.isa(ast.key, 'symbol')
    buffer.push ".#{key}"
  else
    buffer.push "[#{key}]"

register AST.get('member'), compileMember

compileObject = (ast, buffer, level) ->
  # all the inner of the object should be ANF'd here so we are left with literals and symbols.
  buffer.push '{'
  for [ key , val ], i in ast.val
    buffer.push JSON.stringify(key)
    buffer.push ': '
    _compileOne val, buffer, level
    if i < ast.val.length - 1
      buffer.push ', '
  buffer.push '}'

register AST.get('object'), compileObject

compileArray = (ast, buffer, level) ->
  buffer.push '['
  for item, i in ast.val 
    _compileOne item, buffer, level
    if i < ast.val.length - 1
      buffer.push ', '
  buffer.push ']'

register AST.get('array'), compileObject

compileReturn = (ast, buffer, level) ->
  val = ast.val
  loglet.log 'compileReturn', ast, level, val.type()
  if val.type() == 'funcall'
    if level > 0
      buffer.push "return _rt.tail("
    else
      buffer.push "return _rt.tco("
    _compile val.funcall, buffer, level + 1
    for arg in val.args 
      buffer.push ", "
      _compile arg, buffer, level + 1 
  else if level > 0
    buffer.push "return ("
    _compile val, buffer, level + 1 # this didn't increase the counter??? 
  else 
    buffer.push "return _done(null, "
    _compile val, buffer, level + 1 # this didn't increase the counter??? 
  if level == 0 and val.type() == 'funcall'
    buffer.push ", _done);"
  else
    buffer.push ");"
  buffer.newline()

register AST.get('return'), compileReturn 

compileThrow = (ast, buffer, level) ->
  buffer.push "throw "
  _compile ast.val, buffer
  buffer.push ";"
  buffer.newline()

register AST.get('throw'), compileThrow

compileIf = (ast, buffer, level) ->
  condE = _compile ast.if, new LineBuffer(), level
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


###





  
  