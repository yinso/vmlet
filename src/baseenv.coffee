Environment = require './environment'
loglet = require 'loglet'
fs = require 'fs'


class BaseEnv extends Environment
  
baseEnv = new BaseEnv()

baseEnv.define '+', (a, b) -> a + b
baseEnv.define '-', (a, b) -> a - b
baseEnv.define '*', (a, b) -> a * b
baseEnv.define '%', (a, b) -> a % b
baseEnv.define '>', (a, b) -> a > b
baseEnv.define '>=', (a, b) -> a >= b
baseEnv.define '<=', (a, b) -> a <= b
baseEnv.define '<', (a, b) -> a < b
baseEnv.define '==', (a, b) -> a == b
baseEnv.define '!=', (a, b) -> a != b

module.exports = baseEnv
