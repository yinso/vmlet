assert = require 'assert'
Promise = require '../src/promise'
loglet = require 'loglet'

describe 'promise test', ->
  
  it 'defer works', (done) ->
    deferred = Promise.defer()
    deferred
      .promise
      .then (v) ->
        done null
      .catch (e) ->
        done null
    deferred.resolve 'abc'
