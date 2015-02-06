Ref = require './ref'
loglet = require 'loglet'

class Environment
  constructor: (@inner = {}, @prev = null) ->
  has: (key) ->
    if @inner.hasOwnProperty(key)
      true
    else if (@prev instanceof Environment)
      @prev.has key
    else
      false
  get: (key) ->
    if @inner.hasOwnProperty(key)
      @inner[key]
    else if (@prev instanceof Environment)
      @prev.get key
    else
      loglet.error @
      throw {error: 'Environment:invalid_identifier', name: key}
  define: (key, val) ->
    if @inner.hasOwnProperty(key)
      throw {error: 'duplicate_definition', name: key}
    else
      @inner[key] = val
  undefine: (key) ->
    if @inner.hasOwnProperty(key)
      delete @inner[key]
    else if @prev
      @prev.undefine key
  set: (key, val) -> 
    if @inner.hasOwnProperty(key) 
      @inner[key] = val
    else if @prev
      @prev.set key, val
    else
      throw {error: 'invalid_identifier', name: key}
  defineRef: (key) ->
    @define key, new Ref(key)
  newEnvFromParams: (params) ->
    refs = 
      for param in params
        new Ref(param)
    inner = {}
    for ref in refs
      inner[ref.name] = ref
    newEnv = new Environment inner, @
    loglet.debug 'Environment.newEnvFromParams', newEnv, refs, inner, params
    newEnv
  keys: () ->
    Object.keys(@inner)
  show: (level = 0) ->
    tab = () ->
      ('  ' for i in [0...level]).join('')
    for key, val of @inner
      loglet.log tab(), key, '=>', val
    if @prev 
      @prev.show(level + 1)

module.exports = Environment