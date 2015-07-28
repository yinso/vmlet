util = require './util'
Hashmap = require './hashmap'
esnode = require './esnode'
TR = require './trace'

class SymbolTable 
  # strictly speaking we don't need prev? but it's still nice to have it I think.
  constructor: (@prev = null) ->
    @dupes = {}
    @inner = new Hashmap
      hashCode: util.hashCode
  has: (key) ->
    if @inner.has key
      true 
    else if @prev 
      @prev.has key 
    else 
      false
  get: (key) ->
    if @inner.has key
      @inner.get key
    else if @prev
      @prev.get key 
    else
      throw new Error("escompile:unknown_identifier: #{key}")
  alias: (key) -> 
    if @has key 
      @get key
    else 
      newKey = @newKey key 
      @inner.set key, newKey
      newKey
  # can this newkey be generalized? 
  newKey: (key) -> 
    name = key.value
    if not @dupes.hasOwnProperty(name)
      @dupes[name] = 0
    else
      @dupes[name]++ 
    if @dupes[name] == 0
      esnode.identifier(name)
    else
      esnode.identifier(name + "$" + @dupes[name])

module.exports = SymbolTable