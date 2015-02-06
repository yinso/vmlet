Task = require '../src/task'
Environment = require '../src/environment'
loglet = require 'loglet'
CodeBlock = require '../src/codeblock'
assert = require 'assert'
Promise = require '../src/promise'
fs = require 'fs'
path = require 'path'

describe 'task test', ->
  
  canRunTask = (desc, code, expected) ->
    it "can run task #{desc} with #{code}", (done) ->
      task = new Task code
      task.run (err, actual) ->
        if err
          loglet.log '-------------------- ERROR run task', code
          loglet.log expected
          loglet.error err
        else
          try 
            if expected != undefined
              assert.deepEqual actual, expected
            done null
          catch e 
            loglet.log '-------------------- ERROR run task', code
            loglet.log expected
            loglet.log actual
            loglet.error err
            done e
  
  canRunTask 'create array', 
    new CodeBlock()
      .push(3)
      .push(3)
      .push(2)
      .multiply()
      .array(2),
    [3, 6]
  
  canRunTask 'create object',
    new CodeBlock()
      .push('foo')
      .push(2)
      .push('bar')
      .push(4)
      .push(5)
      .minus()
      .object(4),
    {foo: 2, bar: -1}
  
  canRunTask 'if', 
    new CodeBlock()
      .push(true)
      .if()
      .push(2)
      .push(3)
      .plus()
      .else()
      .push(4)
      .push(10)
      .divide()
      .end(),
    5
  ####
  readFile = Promise.nodeify fs.readFile
  
  sleep = Promise.nodeify (ms, cb) ->
    setTimeout (() ->
      loglet.log 'done.sleeping', ms
      cb null), ms
  
  canRunTask 'sleep', 
    new CodeBlock()
      .push(path.join(__dirname, 'task.coffee'))
      .push('utf8')
      .push(readFile)
      .funcall(2),
    undefined
  
  canRunTask 'multiple async', 
    new CodeBlock()
      .push(200)
      .push(sleep)
      .funcall(1)
      .push(path.join(__dirname, 'task.coffee'))
      .push('utf8')
      .push(readFile)
      .funcall(2),
    undefined
  
  canRunTask 'create paramList',
    new CodeBlock()
      .push('foo')
      .param(1)
      .push('bar')
      .param(1)
      .push('baz')
      .param(1)
      .paramList(3),
    undefined
  
  canRunTask 'create/run procedure',
    new CodeBlock()
      .push(1)
      .push(2)
      .push('add') # name
      .push('a') # params
      .param(1) 
      .push('b')
      .param(1)
      .paramList(2)
      # returns? 
      .block()
      .ref('a')
      .ref('b')
      .plus()
      .endBlock()
      .procedure()
      .funcall(2),
    3

