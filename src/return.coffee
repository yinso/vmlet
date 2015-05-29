# return transformation/propagation.
# this transforms 
# reansform from anf to cps
loglet = require 'loglet'
errorlet = require 'errorlet'

AST = require './ast'
ANF = require './anf'
util = require './util'

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
    throw errorlet.create {error: 'RETURN.unsupported_as_type', type: ast.type()}

override = (ast, cps) ->
  types[ast.type] = cps

###
return is a bit difficult to get working. Because it's somewhat context dependent.

return ought to be simple, except where it gets worked together with a few complex constructs.

when we get to return, we have done ASN transformation - it means we should be working from a block at the top level.

ASN has the following format. 

(block 
  (tempVar exp)
  ...
  lastResult)

We will need to make sure that the return gets 

###


propagate = (ast) ->
  loglet.log 'RETURN.propagate', ast
  _propagate ast, 0

_propagate = (ast, level) ->
  propagator = get ast
  propagator(ast, level)

_propagateInner = (ast) ->
  switch ast.type()
    when 'local'
      # this is pretty much the only thing that needs to be deal with now.. 
      # the idea - grab the inner value. 
      # clone the current reference
      val = _propagateLocalItem ast.normalized()
      ast.clone val
    else
      ast

_propagateLocalItem = (ast, level) ->
  switch ast.type()
    when 'procedure', 'task'
      res = _propagate ast 
      if res.type() == 'return'
        res.value
      else
        res
    else
      ast

propagateUnit = (ast, level) ->
  ast

register AST.get('return'), propagateUnit
register AST.get('throw'), propagateUnit

propagateScalar = (ast, level) ->
  AST.make 'return', ast

register AST.get('number'), propagateScalar
register AST.get('string'), propagateScalar
register AST.get('bool'), propagateScalar
register AST.get('null'), propagateScalar
register AST.get('symbol'), propagateScalar
register AST.get('binary'), propagateScalar
register AST.get('funcall'), propagateScalar
register AST.get('member'), propagateScalar
register AST.get('array'), propagateScalar
register AST.get('object'), propagateScalar
register AST.get('ref'), propagateScalar
register AST.get('proxyval'), propagateScalar
register AST.get('taskcall'), propagateScalar

propagateProcedure = (ast, level) ->
  console.log 'RETURN.procedure', ast
  AST.make 'return', AST.make('procedure', ast.name, ast.params, _propagate(ast.body, level + 1))

register AST.get('procedure'), propagateProcedure

propagateTask = (ast, level) ->
  AST.make 'return', AST.make('task', ast.name, ast.params, _propagate(ast.body, level + 1))

register AST.get('task'), propagateTask

propagateLocal = (ast, level) ->
  _propagate ast.normalized(), level + 1 

register AST.get('local'), propagateLocal

#propagateTempvar = (ast, level) ->
#  _propagate ast.value, level + 1
#
#register AST.get('tempvar'), propagateTempvar

propagateDefine = (ast, level) ->
  body = _propagate ast.value, level + 1
  if body.isa('return')
    AST.make('define', ast.name, body.value)
  else
    AST.make 'define', ast.name, body

register AST.get('define'), propagateDefine

propagateIf = (ast, level) ->
  thenE = _propagate ast.then, level
  elseE = _propagate ast.else, level
  AST.make 'if', ast.cond, thenE, elseE

register AST.get('if'), propagateIf

propagateBlock = (ast, level) ->
  items = 
    for item, i in ast.items
      if i < ast.items.length - 1
        _propagateInner item, level + 1
      else
        _propagate item, level + 1
  if items[items.length - 1].type() == 'define'
    items.push AST.make('return', AST.make('proxyval', '_rt.unit'))
  AST.make 'block', items

register AST.get('block'), propagateBlock

propagateCatch = (ast, level) ->
  #loglet.log 'RETURN.propagateCatch', ast
  body = _propagate ast.body, level + 1
  AST.make 'catch', ast.param, body

register AST.get('catch'), propagateCatch

propagateTry = (ast, level) ->
  body = _propagate ast.body, level + 1
  catches = 
    for c in ast.catches
      _propagate c, level + 1
  #loglet.log 'RETURN.propagateTry', body, catches
  AST.make 'try', body, catches, ast.finally

register AST.get('try'), propagateTry

module.exports = 
  register: register
  get: get
  override: override
  transform: propagate
