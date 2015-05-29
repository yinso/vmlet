AST = require './ast'
T = require './transformer'
tr = require './trace'

# when this is called it would be ANF'd.
atomicTypes = 
  ['string', 'procedure', 'bool', 'null', 'undefined', 'number', 'procedure', 'task', 'binary', 'funcall']

T.register 'return', ($r) ->
  $r.value.type() in atomicTypes
, ($r) -> $r

T.register 'return', ($r) ->
  $r.value.type() == 'block'
, ($r) -> 
  AST.block(for item, i in $r.value.items
    if i < $r.value.items.length - 1 
      T.transform item
    else
      T.transform AST.return(item)
  )

T.register 'return', ($r) -> 
  $r.value.type() == 'return'
, ($r) -> $r.value

T.register 'return', ($r) -> 
  $r.value.type() == 'throw'
, ($r) -> $r.value

T.register 'return', ($r) ->
  if $r.value.type() == 'local'
    [ $r.value.normalized() ]
  else
    false
, ($r, $inner) -> 
  #console.log '-- return.local', arguments
  T.transform AST.return($inner)

T.register 'return', ($r) ->
  if $r.value.type() == 'if'
    [ $r.value.cond , $r.value.then, $r.value.else ]
, ($r, $cond, $then, $else) -> 
  thenExp = T.transform AST.return $then
  elseExp = T.transform AST.return $else
  AST.if $cond, thenExp, elseExp

T.register 'return', ($r) -> 
  if $r.value.type() == 'try'
    [ $r.value.body, $r.value.catches, $r.value.finally ]
  else
    false
, ($r, $body, $catches, $finally) ->
  body = T.transform AST.return($body)
  catches = 
    for handler in $catches
      T.transform AST.return(handler)
  final = T.transform $finally
  AST.try body, catches, final

T.register 'return', ($r) -> 
  if $r.value.type() == 'catch'
    [ $r.value.param, $r.value.body ]
  else
    false
, ($r, $param, $body) -> 
  AST.catch $param, T.transform AST.return($body)

T.register 'return', ($r) -> 
  if $r.value.type() == 'finally'
    $r.value
  else 
    false
, ($r, $finally) -> 
  T.transform $finally

T.register 'local', ($l) -> 
  val = $l.normalized()
  val.type() in atomicTypes
, ($l) -> $l

T.register 'local', ($l) -> 
  val = $l.normalized()
  console.log 'local.if', val.type() == 'if', val
  if val.type() == 'if'
    [ val.cond, val.then, val.else ]
, ($l, $cond, $then, $else) ->
  thenExp = T.transform $l.assign $then
  elseExp = T.transform $l.assign $else
  AST.block [
    $l.noInit()
    AST.if($cond, thenExp, elseExp)
  ]

T.register 'local', ($l) -> 
  val = $l.normalized()
  if val.type() == 'block'
    val.items
  else
    false
, ($l, $items...) ->
  items = [ $l.noInit() ]
  for item, i in $items 
    if i < $items.length - 1
      items.push T.transform item 
    else
      items.push T.transform AST.assign($l.name(), item)
  AST.block items

T.register 'local', ($l) -> 
  val = $l.normalized()
  if val.type() == 'try'
    [ val.body, val.catches, val.finally ]
  else
    false
, ($l, $body, $catches, $finally) -> 
  body = T.transform AST.assign $l.name, $body
  catches = 
    for handler in $catches 
      T.transform AST.assign $l.name, handler
  final = T.transform $finally
  AST.block [ 
    $l.noInit()
    AST.try(body, catches, final)
  ]

T.register 'assign', ($a) ->
  $a.value.type() in atomicTypes
, ($a) -> $a

T.register 'assign', ($a) -> 
  if $a.value.type() in 'block'
    $a.value.items
, ($a, $items...) ->
  AST.block(for item, i in $items
    if i < $items.length - 1 
      T.transform item 
    else
      T.transform AST.assign($a.name, item)
  )

T.register 'assign', ($a) ->
  if $a.value.type() == 'if'
    [ $a.value.cond, $a.value.then, $a.value.else ]
  else
    false
, ($a, $cond, $then, $else) ->
  AST.if $cond, 
    T.transform(AST.assign($a.name, $cond)),
    T.transform(AST.assign($a.name, $else))

T.register 'assign', ($a) -> 
  if $a.value.type() == 'try'
    [ $a.value.body, $a.value.catches , $a.value.finally ]
  else
    false
, ($a, $body, $catches, $finally) -> 
  body = T.transform AST.assign($a.name, $body)
  catches = 
    for handler in $catches
      T.transform AST.assign($a.name, handler)
  final = T.transform $finally
  AST.try body, catches, final

T.register 'assign', ($a) -> 
  if $a.value.type() == 'catch'
    [ $a.value.param , $a.value.body ]
  else
    false
, ($a, $param, $body) -> 
  AST.catch $param, T.transform(AST.assign $a.name, $body)

T.register 'procedure', ($p) -> 
  [ $p.name , $p.params, $p.body , $p.returns ]
, tr.trace 'proc.trans', ($p, $name, $params, $body, $returns) -> 
  body = T.transform AST.return($body)
  AST.procedure $name, $params, body, $returns

T.register 'task', ($p) -> 
  [ $p.name , $p.params, $p.body , $p.returns ]
, ($p, $name, $params, $body, $returns) -> 
  body = T.transform AST.return($body)
  AST.task $name, $params, body, $returns


  
