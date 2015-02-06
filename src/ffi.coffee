# class built-in function -> this is a function...
# it will also be an opcode?
Promise = require './promise'

registerAsync = (proc) ->
  proc = Promise.nodeify(proc)
  proc.__vmlet = 
    async: true

registerSync = (proc) ->
  proc.__vmlet = 
    sync: true
    

module.exports = 
  registerAsync: registerAsync