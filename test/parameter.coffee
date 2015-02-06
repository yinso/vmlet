Parameters = require '../src/parameter'
AST = require '../src/ast'
assert = require 'assert'
loglet = require 'loglet'

describe 'parameter test', ->
  
  mapParams = (plist, args, expected) ->
    #loglet.log '----------mapParams', plist, args, expected
    it "can map #{plist}", (done) ->
      try 
        result = plist.normalize args
        assert.deepEqual result, expected
        done null
      catch e
        done e
  
  plist1 = Parameters.make [
    Parameters.makeParam 'a'
    Parameters.makeParam 'b'
  ]
  
  mapParams plist1, [1, 2], {a: 1, b: 2}
  
  plist2 = Parameters.make [
    Parameters.makeParam 'a'
    Parameters.makeParam 'b', null, AST.make('number', 5)
    Parameters.makeParam 'c'
  ]
  
  mapParams plist2, [1, 2], {a: 1, b: null, c: 2}
  
  plist3 = Parameters.make [
    Parameters.makeParam 'a'
    Parameters.makeParam 'b', null, AST.make('number', 5)
    Parameters.makeParam 'c'
    Parameters.makeParam 'd', null, AST.make('bool', true)
  ]
  
  mapParams plist3, [1, 2], {a: 1, b: null, c: 2, d: null}
  mapParams plist3, [1, 2, 3], {a: 1, b: 2, c: 3, d: null}
  mapParams plist3, [1, 2, 3, false], {a: 1, b: 2, c: 3, d: false}
  