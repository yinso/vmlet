Environment = require './environment'
loglet = require 'loglet'
fs = require 'fs'

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
    @define key, @makeSync funcMaker
  defineAsync: (key, funcMaker) ->
    @define key, @makeAsync funcMaker
  
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
baseEnv.define 'console', console

module.exports = baseEnv
