Task = require './task'
baseEnv = require './baseenv'
Environment = require './environment'
compiler = require './compiler'
parser = require './parser'
loglet = require 'loglet'
Procedure = require './procedure'

class VM
  @Procedure: Procedure
  @compiler: compiler
  @parser: parser
  @Task: Task
  constructor: (@options = {}) ->
    @baseEnv = @options.baseEnv or baseEnv
    @parser = @options.parser or parser
    @compiler = @options.compiler or compiler
  eval: (stmt, cb) ->
    asts = null
    code = null
    try 
      ast = @parser.parse stmt
      code = @compiler.compile ast, @baseEnv
      task = new Task code, @baseEnv
      task.run cb
    catch e 
      loglet.log 'VM.evalError', stmt, asts, code
      cb e

module.exports = VM
