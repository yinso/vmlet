AST = require './ast'
Hashmap = require './hashmap'
TR = require './trace'

class SymbolTable 
  @defaultOptions: 
    newSym: true
  @make: (options = @defaultOptions) -> 
    new @(options)
  constructor: (@options) ->
    @dupes = {}
    @inner = new Hashmap()
    @temp = 0
    @prev = null
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
      throw new Error("SymbolTable:unknown_identifier: #{key}")
  alias: (key) -> 
    if @has key 
      @get key
    else 
      val = 
        if @options.newSym 
          @newKey key 
        else
          key
      ref = AST.ref key, val
      @inner.set key, ref
      ref
  gensym: (sym = null) ->
    if sym 
      @newKey sym
    else
      AST.symbol @newName("_")
  defineTemp: (ast) -> 
    sym = @gensym()
    ref = @alias sym
    ref.value = ast
    ref
  newName: (name) -> 
    if not @dupes.hasOwnProperty(name)
      @dupes[name] = 0
    else
      @dupes[name]++ 
    if @dupes[name] == 0
      name
    else
      "#{name}$#{@dupes[name]}"
  newKey: (key) -> 
    AST.symbol @newName(key.value)
  pushEnv: () -> 
    newEnv = @constructor.make(@options)
    newEnv.prev = @
    newEnv
  toString: () -> 
    "<env>"

module.exports = SymbolTable
