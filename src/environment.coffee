AST = require './ast'
loglet = require 'loglet'
HashMap = require './hashmap'

_hashCode = (str) ->
  val = 0
  for i in [0...str.length]
    char = str.charCodeAt i 
    val = ((val<<5) - val) + char
    val = val & val
  val

class Environment
  constructor: (@prev = null) ->
    #@inner = new HashMap 
    #  hashCode: _hashCode
    @inner = new HashMap 
      hashCode: (v) ->
        v.hashCode()
        #if v instanceof AST 
        #  v.hashCode()
        #else
        #  _hashCode v 
      equals: (v, v1) -> 
        v.equals(v1)
        #if (v instanceof AST)
        #  v.equals(v1)
        #else
        #  v == v1 
  has: (key) ->
    if @inner.has(key)
      true
    else if (@prev instanceof Environment)
      @prev.has key
    else
      false
  get: (key) ->
    if @inner.has(key)
      @inner.get(key)
    else if (@prev instanceof Environment)
      @prev.get key
    else
      loglet.error @
      throw {error: 'Environment:invalid_identifier', name: key}
  define: (key, val) ->
    if @inner.has(key)
      throw {error: 'duplicate_definition', name: key}
    else
      @inner.set key, val
      val
  undefine: (key) ->
    if @inner.has(key)
      @inner.delete key
    else if @prev
      @prev.undefine key
  set: (key, val) -> 
    if @inner.has(key) 
      @inner.set key, val
    else if @prev
      @prev.set key, val
    else
      throw {error: 'invalid_identifier', name: key}
  show: (level = 0) ->
    tab = () ->
      ('  ' for i in [0...level]).join('')
    for key, val of @inner.keyVals()
      loglet.log tab(), key, '=>', val
    if @prev 
      @prev.show(level + 1)

module.exports = Environment