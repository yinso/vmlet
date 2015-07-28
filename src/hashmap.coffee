util = require './util'

# expects hashCode and equals
class HashMap
  @defaultOptions:
    hashCode: util.hashCode
    equals: (k, v) -> k == v
  constructor: (options = {}) ->
    Object.defineProperty @, 'buckets',
      readonly: true
      value: []
    Object.defineProperty @, 'hashCode',
      readonly: true 
      value: options.hashCode or @constructor.defaultOptions.hashCode
    Object.defineProperty @, 'equals', 
      readonly: true 
      value: options.equals or @constructor.defaultOptions.equals
  set: (key, val) ->
    hashCode = @hashCode key
    @buckets[hashCode] = @buckets[hashCode] or []
    for kv in @buckets[hashCode]
      if @equals kv.key, key
        kv.val = val
        return @
    @buckets[hashCode].push {key: key, val: val}
    @
  _get: (key) ->
    hashCode = @hashCode key
    for kv in @buckets[hashCode] or [] 
      if @equals kv.key, key
        return kv
    undefined
  get: (key) ->
    res = @_get key
    if res 
      res.val
    else
      res
  has: (key) ->
    res = @_get key
    res instanceof Object
  delete: (key) ->
    hashCode = @hashCode key
    if not @buckets.hasOwnProperty(hashCode)
      return false
    count = -1 
    for kv, i in @buckets[hashCode] 
      if @equals kv.key, key
        count = i
    if count != -1
      @buckets[hashCode].splice count, 1
      true 
    else
      false
  keys: () -> 
    keys = []
    for hasCode, bucket of (@buckets or {})
      for {key, val} in bucket 
        keys.push key
    keys
  values: () -> 
    vals = []
    for hasCode, bucket of (@buckets or {})
      for {key, val} in bucket 
        vals.push val
    vals
  
module.exports = HashMap 
  