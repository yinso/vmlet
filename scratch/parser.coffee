parser = require '../grammar/indent'
fs = require 'fs'
path = require 'path'
funclet = require 'funclet'
loglet = require 'loglet'
assert = require 'assert'

describe 'parser test', () ->
  canParseFile = (filePath, expected) ->
    it "can parse file: #{filePath}", (done) ->
      funclet.bind(fs.readFile, filePath,'utf8')
        .then (data, next) ->
          parsed = parser.parse(data)
          next null, parsed
        .catch(done)
        .done (parsed) ->
          assert.deepEqual expected, parsed
          done null
  
  canParseFile path.join(__dirname, '..','example','t1.ame'), 
    a: [
      'b'
      'c'
      {
        d: [
          'z'
          'y'
          'x'
        ]
      }
    ] 
      
  canParseFile path.join(__dirname, '..', 'example', 't2.ame'),
    html: [
    
    ]
  