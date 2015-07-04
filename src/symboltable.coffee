AST = require './ast'
HashMap = require './hashmap'
tr = require './trace'

# 
# a symbol table that will hold all of the hierarchical needs of the symbols...
# we also need to figure out 
# stay unique isn't too hard apparently. but getting swapped out can be difficult... 
# we need the ability to pull things in... ??? 
# or maybe that's not necessary? 
# 
# DEFINE SYM|REF VAL
# LOCAL SYM|REF VAL
# ASSIGN SYM|REF VAL
# 
# PROC SYM|REF? VAL 
# TASK SYM|REF? VAL
# 

class SymbolTable
  constructor: (@prev = null) ->
    @inner = {}
    @temp = 0
  has: (sym) ->
    # we can really just store strings? 
    if @_has sym
      true 
    else if @prev 
      @prev.has sym
    else
      false
  _has: (sym) ->
    @inner.hasOwnProperty(sym.value)
  get: (sym) ->
    if @inner.hasOwnProperty(sym.value)
      @inner[sym.value]
    else
      @prev?.get(sym) or undefined
  define: (sym, val) -> # returns the REF. this is where we are tracking for somethings very specific...
    console.log 'SymbolTable.define', sym, val, @inner
    if @_has sym
      throw new Error("duplicate_identifier: #{sym}")
    else if @prev?.has sym 
      ref = AST.ref(sym.nested(), val)
      @inner[sym.value] = ref 
      ref
    else
      ref = AST.ref(sym, val)
      @inner[sym.value] = ref
      ref
  gensym: (sym = null) ->
    if sym 
      AST.symbol "#{sym.value}$#{@temp++}"
    else
      AST.symbol "_$#{@temp++}"
  defineParam: (param) ->
    ref = @define param.name, param 
    param
  defineTemp: (val) ->
    sym = @gensym()
    @define sym, val
  set: (sym, val) -> # this is something that really isn't needed any more...
    if not @_has sym 
      throw new Error("undefined_identifier: #{sym}")
    ref = @get sym 
    ref.value = val 
    ref 
  del: (sym) ->
    if @_has sym 
      delete @inner[sym.value]
  level: () ->
    count = 0
    current = @prev 
    while current instanceof SymbolTable
      count++
      current = current.prev
    count

module.exports = SymbolTable 
