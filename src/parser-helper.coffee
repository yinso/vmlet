AST = require './ast'
loglet = require 'loglet'

number = (num, frac, exp) ->
  AST.make 'number', parseFloat [num, frac, exp].join('')

bool = (val) ->
  AST.make 'bool', val

nullAST = () ->
  AST.make 'null', null

operator = (lhs, rest) ->
  helper = (lhs, rhs) ->
    AST.make 'binary', rhs.op, lhs, rhs.rhs
  if rest.length == 0
    return lhs
  temp = lhs
  while rest.length > 0
    temp = helper temp, rest.shift()
  temp

object = (keyVals) ->
  AST.make 'object', keyVals

array = (items) ->
  AST.make 'array', items

symbol = (c1, rest) ->
  sym = [ c1 ].concat(rest).join('')
  switch sym
    when 'true'
      AST.make 'bool', true
    when 'false'
      AST.make 'bool', false
    when 'null'
      AST.make 'null', null
    else
      AST.make 'symbol', sym

string = (chars) ->
  str = if chars instanceof Array then chars.join('') else chars
  AST.make 'string', str

class ArgsArray
  constructor: (@args) ->
    
argsArray = (args) ->
  new ArgsArray args

member = (head, keys) ->
  result = head
  for key in keys 
    if key instanceof ArgsArray
      result = AST.make 'funcall', result, key.args
    else
      result = AST.make 'member', result, key
  result

block = (exps) ->
  if exps.length == 1
    exps[0]
  else
    AST.make 'block', exps

ifAST = (condE, thenE, elseE) ->
  AST.make 'if', condE, thenE, elseE

define = (id, val) ->
  #AST.make 'define', id.value, val
  AST.make 'define', id, val

param = (name) ->
  AST.make 'param', name

funcDecl = (name, params, body, returns = null) ->
  #AST.make 'procedure', (if name then name.value else name), params, body, returns
  AST.make 'procedure', name, params, body, returns

taskDecl = (name, params, body, returns = null) ->
  #AST.make 'task', (if name then name.value else name), params, body, returns
  AST.make 'task', name, params, body, returns

funcall = (proc, args) ->
  AST.make 'funcall', proc, args

taskcall = (inner) ->
  if AST.isa(inner, 'funcall')
    # await is an async funcall...
    AST.make 'taskcall', inner.funcall, inner.args
  else
    inner

throwAST = (e) ->
  AST.make 'throw', e

finallyAST = (body) ->
  AST.make 'finally', body

catchAST = (param, body) ->
  AST.make 'catch', param, body

tryAST = (body, catches, fin) ->
  AST.make 'try', body, catches, fin

import_ = (module, defs = []) ->
  AST.import module, defs

export_ = (spec) ->
  AST.export spec

binding = (spec, as = null) ->
  AST.binding spec, as

let_ = (id, defines, body) ->
  params = 
    for def in defines 
      def.name 
  args = 
    for def in defines 
      def.value 
  AST.funcall(AST.procedure(id, params, body), args)


letTask = (id, defines, body) ->
  params = 
    for def in defines 
      AST.param(def.name)
  args = 
    for def in defines 
      def.value 
  AST.taskcall(AST.task(id, params, body), args)

module.exports = 
  number: number
  bool: bool
  operator: operator
  object: object
  array: array
  symbol: symbol
  string: string
  member: member
  block: block
  if: ifAST
  null: nullAST
  define: define
  arguments: argsArray
  param: param
  function: funcDecl
  task: taskDecl
  funcall: funcall
  taskcall: taskcall
  throw: throwAST
  try: tryAST
  catch: catchAST
  finally: finallyAST
  import: import_
  export: export_
  binding: binding
  let: let_
  letTask: letTask


