# return transformation/propagation.
# this transforms 
# reansform from anf to cps
loglet = require 'loglet'
errorlet = require 'errorlet'

AST = require './ast'
ANF = require './anf'
util = require './util'
RET = require './return'

types = {}

register = (ast, cps) ->
  if types.hasOwnProperty(ast.type)
    throw errorlet.create {error: 'RETURN.duplicate_ast_type', type: ast.type}
  else
    types[ast.type] = cps
  
get = (ast) ->
  if types.hasOwnProperty(ast.type())
    types[ast.type()]
  else
    throw errorlet.create {error: 'RETURN.unsupported_as_type', type: ast}

override = (ast, cps) ->
  types[ast.type] = cps

normalize = (ast) ->
  block = AST.make 'block'
  _normalize ast, block

_normalize = (ast, block) ->
  normalizer = get ast 
  normalizer ast, block

makeBlock = (type) ->
  (ast) ->
    items = 
      for item, i in ast.items
        if i < item.length - 1
          _normalize item
        else
          RET.transform item
    AST.make type, items

_normalizeBlock = makeBlock 'block'

register AST.get('block'), _normalizeBlock

_normalizeANF = makeBlock 'anf'

register AST.get('anf'), _normalizeANF

makeProc = (type) ->
  (ast) ->
    AST.make type, ast.name, ast.params, _normalize(ast.body)

register AST.get('procedure'), makeProc('procedure')
register AST.get('task'), makeProc('task')

normalizeScalar = (ast) -> 
  ast

register AST.get('number'), normalizeScalar
register AST.get('string'), normalizeScalar
register AST.get('null'), normalizeScalar
register AST.get('symbol'), normalizeScalar
register AST.get('proxyval'), normalizeScalar
register AST.get('ref'), normalizeScalar
register AST.get('member'), normalizeScalar

normalizeIf = (ast) ->
  AST.make 'if', _normalize(ast.cond), _normalize(ast.then), _normalize(ast.else)

register AST.make('if'), normalizeIf

normalizeTempvar = (ast) ->
  


module.exports = 
  register: register
  get: get
  override: override
  transform: normalize
