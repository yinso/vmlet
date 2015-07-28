AST = require './ast'
T = require './transformer'
tr = require './trace'
CPS = require './cps'
TCO = require './tail'
CLONE = require './clone'

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
    [ $r.value.value ]
  else
    false
, ($r, $inner) -> 
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
  final = 
    if $finally 
      T.transform $finally
    else
      null 
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

T.register 'return', ($r) ->
  if $r.value.type() == 'let'
    [ $r.value.defines , $r.value.body ]
, ($r, $defines , $body) -> 
  AST.let $defines, T.transform AST.return($body)

T.register 'local', ($l) -> 
  if not $l.value
    return false
  val = $l.value
  val.type() in atomicTypes
, ($l) -> $l

T.register 'local', ($l) -> 
  if not $l.value
    return false
  val = $l.value
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
  if not $l.value
    return false
  val = $l.value
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
  if not $l.value
    return false
  val = $l.value
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
  if $a.value.type() == 'block'
    $a.value.items
  else
    false
, ($a, $items...) ->
  items = 
    for item, i in $items
      if i < $items.length - 1 
        T.transform item 
      else
        T.transform AST.assign($a.name, item)
  AST.block items

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
, ($p, $name, $params, $body, $returns) -> 
  newParams = 
    for param in $params 
      CLONE.transform param
  locals = 
    for param, i in $params 
      AST.local param.name, newParams[i].ref()
  body = 
    if $body.type() == 'block'
      AST.block locals.concat($body.items)
    else
      AST.block locals.concat($body)
  body = T.transform AST.return(body)
  body = 
    if body.type() == 'block'
      body
    else
      AST.block [ body ]
  # this make sure that we don't lose the references that points to this procedure.
  $p.params = newParams 
  $p.body = body
  TCO.transform $p

T.register 'task', ($p) -> 
  [ $p.name , $p.params, $p.body , $p.returns ]
, ($p, $name, $params, $body, $returns) -> 
  body = T.transform AST.return($body)
  CPS.transform AST.task $name, $params, body, $returns

T.register 'toplevel', ($t) ->
  [ $t.body ]
, ($t, $body) ->
  body = T.transform $body 
  CPS.transform $t.clone(body)

T.register 'module', ($t) ->
  [ $t.body ]
, ($t, $body) -> 
  body = T.transform $body 
  CPS.transform $t.clone body

