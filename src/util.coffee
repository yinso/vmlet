
isFunction = (func) ->
  typeof(func) == 'function' or func instanceof Function

isAsync = (func) ->
  isFunction(func) and func.__vmlet?.async

isSync = (func) ->
  isFunction(func) and not (func.__vmlet.async)

class Pair
  @empty: new @()
  @list: (ary = []) ->
    head = null 
    for i in [ary.length - 1..0]
      head = @cons ary[i], head
    head
  @cons: (head, tail = @empty) ->
    new @ head, tail 
  constructor: (@head, @tail) ->
  has: (item) ->
    if @head == item 
      true
    else if @isEmpty()
      false
    else
      @tail.has(item)
  isEmpty: () ->
    @head == @tail == undefined

decycle = (obj, cache = [ ]) -> 
  cache.push obj
  if typeof(obj) != 'object'
    obj
  else if obj instanceof Array 
    decycleArray obj, cache
  else 
    decycleObject obj, cache

class Dupe
  constructor: () ->
  toString: () -> 
    '#<ref>'

decycleArray = (ary, cache) ->
  res = []
  for item, i in ary 
    if typeof(item) != 'object'
      res.push item
    else if cache.indexOf(item) == -1 
      cache.push item
      res.push decycle(item, cache)
    else # it exists... 
      res.push new Dupe(item)
  res

decycleObject = (obj, cache) -> 
  res = {}
  for key, val of obj 
    if obj.hasOwnProperty(key)
      if typeof(obj) != 'object'
        res[key] = val
      else if cache.indexOf(val) == -1
        cache.push val 
        res[key] = decycle(val, cache)
      else
        res[key] = new Dupe(val)
  res

## how about iolist??

addDupe = (item, dupe) ->
  (if typeof(item) == 'object' then Pair.cons(item, dupe) else dupe)

nest = (level) ->
  ['\n', ('  ' for i in [0...level]) ]

prettyArray = (ary, level, dupe) ->
  [
    '[ '
    (for item, i in ary
      if i > 0
        [
          ', '
          if dupe.has(item)
            '#<dupe>'
          else
            pretty(item, level + 1, addDupe(item, dupe))
        ]
      else 
        if dupe.has(item)
          '#<dupe>'
        else
          pretty(item, level + 1, addDupe(item, dupe)))
    ' ]'
  ]

prettyKeyVal = (key, val, level, dupe) ->
  if val == undefined
    [ ]
  else
    [ nest(level), key, ': ', pretty(val, level, dupe) ]

prettyObject = (obj, level, dupe) ->
  if isFunction obj._pretty
    return obj._pretty(level)
  lines = []
  lines.push '{'
  hasItem = false
  for key, val of obj 
    if obj.hasOwnProperty(key)
      lines.push prettyKeyVal(key, val, level + 1)
      hasItem = true
  if hasItem
    lines.push nest(level), '}'
  else
    lines.push ' }'
  lines

pretty = (obj, level = 0, dupe = Pair.empty) ->
  # we will just do regular printing at this time... 
  switch typeof(obj)
    when 'undefined'
      [ 'undefined' ]
    when 'boolean'
      [ if obj then 'true' else 'false' ]
    when 'number'
      [ obj.toString() ]
    when 'string'
      [ JSON.stringify(obj) ]
    when 'function'
      [ '[FUNCTION]' ]
    else # object... 
      if obj == null 
        [ 'null' ]
      else if obj instanceof Dupe
        [ obj.toString() ]
      else if obj instanceof Array 
        if dupe.has(obj)
          [ '#<dupe>' ]
        else
          prettyArray obj, level, Pair.cons(obj, dupe)
      else
        if dupe.has(obj)
          [ '#<dupe>' ]
        else
          prettyObject obj, level, Pair.cons(obj, dupe)

flatten = (ary, res = []) ->
  for item, i in ary 
    if item instanceof Array 
      flatten item, res 
    else
      res.push item 
  res

stringify = (obj) ->
  #console.log '--stringify', obj
  flatten(pretty(obj)).join('')

module.exports = 
  isFunction: isFunction
  isAsync: isAsync
  isSync: isSync
  stringify: stringify
  