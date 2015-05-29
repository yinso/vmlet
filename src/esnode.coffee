
identifier = (name) ->
  {type: 'Identifier', name: name}

literal = (val) ->
  {type: 'Literal', value: val}

null_ = () ->
  literal null

undefined_ = () ->
  identifier 'undefined'

member = (obj, key) ->
  type: 'MemberExpression'
  computed: false
  object: obj
  property: key

funcall = (proc, args) ->
  type: 'CallExpression'
  callee: proc
  arguments: args

object = (keyvals) ->
  propHelper = (key, val) ->
    type: 'Property'
    computed: false
    key: identifier(key)
    value: val
    kind: 'init'
    method: false
    shorthand: false
  type: 'ObjectExpression'
  properties: 
    for [key, val] in keyvals
      propHelper key, val

array = (items) ->
  type: 'ArrayExpression'
  elements: items

if_ = (cond, thenExp, elseExp) ->
  type: 'IfStatement'
  test: cond
  consequent: thenExp
  alternate: elseExp

block = (stmts) ->
  type: 'BlockStatement'
  body: stmts

declare = (type, nameVals...) ->
  helper = (name, val) ->
    type: 'VariableDeclarator'
    id: name
    init: val
  type: 'VariableDeclaration'
  kind: type
  declarations: 
    for [name, val] in nameVals
      helper name, val

assign = (name, val) ->
  type: 'AssignmentExpression'
  operator: '='
  left: name
  right: val

function_ = (name, params, body) ->
  type: 'FunctionExpression'
  id: identifier(name)
  params: params
  defaults: []
  body: body

return_ = (value) ->
  type: 'ReturnStatement'
  argument: value

binary = (op, lhs, rhs) ->
  type: 'BinaryExpression'
  operator: op
  left: lhs
  right: rhs

throw_ = (val) ->
  type: 'ThrowStatement'
  argument: val

catch_ = (param, body) ->
  type: 'CatchClause'
  param: param 
  body: body

try_ = (block, catchHandlers, finalHandler = null) ->
  res = 
    type: 'TryStatement'
    block: block
    handlers: catchHandlers
    handler: if catchHandlers.length > 0 then catchHandlers[0] else null
    finalizer: finalHandler

module.exports = 
  identifier: identifier
  literal: literal
  null_: null_
  undefined_: undefined_
  member: member
  funcall: funcall
  object: object
  array: array
  if: if_
  block: block
  declare: declare
  assign: assign
  function: function_
  return: return_
  binary: binary
  throw: throw_
  catch: catch_ 
  try: try_


