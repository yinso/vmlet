Environment = require './environment'
loglet = require 'loglet'
fs = require 'fs'
AST = require './ast'

# by default there are no modules to be loaded for 

class BaseEnv extends Environment
  makeSync: (funcMaker) ->
    func = funcMaker @
    Object.defineProperty func, '__vmlet',
      value: {sync: true}
    func
  makeAsync: (funcMaker) ->
    func = funcMaker @
    Object.defineProperty func, '__vmlet',
      value: {async: true}
    func
  defineSync: (key, funcMaker) ->
    @define AST.symbol(key), @makeSync funcMaker
  defineAsync: (key, funcMaker) ->
    @define AST.symbol(key), @makeAsync funcMaker
  
baseEnv = new BaseEnv()

baseEnv.defineSync '+', (_rt) -> (a, b) -> a + b
baseEnv.defineSync '-', (_rt) -> (a, b) -> a - b
baseEnv.defineSync '*', (_rt) -> (a, b) -> a * b
baseEnv.defineSync '%', (_rt) -> (a, b) -> a % b
baseEnv.defineSync '>', (_rt) -> (a, b) -> a > b
baseEnv.defineSync '>=', (_rt) -> (a, b) -> a >= b
baseEnv.defineSync '<=', (_rt) -> (a, b) -> a <= b
baseEnv.defineSync '<', (_rt) -> (a, b) -> a < b
baseEnv.defineSync '==', (_rt) -> (a, b) -> a == b
baseEnv.defineSync '!=', (_rt) -> (a, b) -> a != b
baseEnv.defineSync 'isNumber', (_rt) ->
  (a) -> 
    typeof(a) == 'number' or a instanceof Number
baseEnv.define AST.symbol('console'), console

module.exports = baseEnv
