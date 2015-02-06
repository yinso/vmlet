loglet = require 'loglet'
Environment = require './environment'
Compiler = require './compiler'
Parser = require './parser'
Task = require './task'
baseEnv = require './baseenv'
Func = require './function'

class Runtime
  @Func: Func
  constructor: (@base = baseEnv) ->
    @compiler = new Compiler()
  define: (key, val) ->
    @base.define key, val
  parse: (code) ->
    Parser.parse code
  compile: (code, env = @base) ->
    code = @compiler.compile code, env
    Task.userBlock code, env
  eval: (stmt, env, cb) ->
    if arguments.length == 2
      cb = env
      env = @base
    try 
      proc = @compile stmt, env
      proc cb
    catch e
      cb e

module.exports = Runtime
