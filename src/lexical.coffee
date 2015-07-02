Environment = require './environment'
AST = require './ast'

# the number here is guaranteed to be smaller than 62.
helper = (num) ->
  if 0 <= num <= 9
    num.toString()
  else if 10 <= num <= 35
    String.fromCharCode num + 55 # upper case A-Z
  else if 36 <= num <= 61 
    String.fromCharCode num + 61
  else
    'z'

numToBase62 = (num) ->
  res = []
  loop
    remainder = num % 62 
    res.unshift helper(remainder)
    num = Math.floor num / 62 
    break if num < 62
  res.join('')

class GensymTable
  constructor: () ->
    @tempName = 0
    @inner = {}
  gensym: (prefix = '__') ->
    prefix + "$" + @symid(prefix)
  symid: (prefix = '__') ->
    @inner[prefix] = @inner[prefix] or 0
    @inner[prefix]++
  temp: () ->
    name = "_$" + numToBase62(@tempName++) 
    AST.symbol name 

class LexicalEnvironment extends Environment
  @defaultPrefix = '___'
  @fromParams: (params, prev = baseEnv) ->
    env = new @ {}, prev
    for param in params
      env.defineParam param
    env
  constructor: (prev = null) ->
    super {}, prev
    @symMap = 
      if @prev instanceof @constructor
        @prev.symMap
      else
        new GensymTable()
  defineParam: (param) ->
    @define param.name, param
    param
  defineLocal: (name, val) ->
    sym = @symMap.gensym name 
    @define name, AST.symbol(sym)
    sym 
  mapParam: (param) ->
    sym = @defineRef param.name
    AST.make 'param', sym, param.type, param.default
  defineTemp: (exp) ->
    sym = @symMap.temp()
    @define sym.value, exp 
    sym 
  gensym: (prefix = LexicalEnvironment.defaultPrefix) ->
    @symMap.gensym prefix
  assign: (val, sym = LexicalEnvironment.defaultPrefix) ->
    varName = @gensym sym
    @define varName, val
    varName
  level: () ->
    count = 0
    current = @prev 
    while current instanceof LexicalEnvironment
      count++
      current = current.prev
    count

module.exports = LexicalEnvironment
