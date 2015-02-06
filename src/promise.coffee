Promise = require 'lie'
loglet = require 'loglet'

Promise.nodeify = (proc) ->
  # the question is - how do I know when I have passed in a function call at the end versus not?
  # if I test it - I will have to make sure I never use things other than cb... 
  result = (args..., cb) ->
    isCBFunction = (typeof(cb) == 'function' or cb instanceof Function)
    if not isCBFunction
      args.push cb
    promise = new Promise (resolve, reject) ->
      proc args..., (err, data) ->
        if err
          reject err
        else
          resolve data
    if isCBFunction 
      promise
        .then (res) ->
          cb null, res
        .catch (err) ->
          cb err
    else
      promise
  result.__vmlet = 
    async: true
  result

Promise.Deferred = class Deferred
  constructor: (@promise, @resolve, @reject) ->

Promise.defer = () ->
  resolve = null
  reject = null
  p = new Promise () ->
    resolve = arguments[0]
    reject = arguments[1]
  new Deferred p, resolve ,reject

module.exports = Promise
