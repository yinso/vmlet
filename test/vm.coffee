VM = require '../src/vm'
loglet = require 'loglet'
assert = require 'assert'
errorlet = require 'errorlet'

describe 'vm test', ->
  
  vm = new VM()
  
  canEval = (stmt, expected) ->
    it "can eval #{stmt}", (done) ->
      
      vm.eval stmt, (err, actual) ->
        errorHelper = (err) ->
          loglet.log '------------- VM.canEval.ERROR', stmt
          loglet.log expected
          loglet.log actual
          loglet.error err
          done err
        
        if err 
          errorHelper err
        else
          try 
            assert.deepEqual actual, expected
            done null
          catch e
            errorHelper e
  
  canEvalError = (stmt) ->
    it "can eval #{stmt}", (done) ->
      vm.eval stmt, (err, actual) ->
        if err 
          done null
        else
          loglet.log '-------------- VM.canEvalError:unexpectedPass', stmt
          loglet.log actual
          done errorlet.create {error: 'unexpected_pass', stmt: stmt, result: actual}
  
  canEval "1", 1
  canEval "1 + 1", 2
  canEval "(1 + 2) * 3", 9
  canEval "(if true then 1 else 2)", 1
  canEval "(function (a, b) a + b)(1 , 2)", 3
  canEval "{ 1 2 3 4 5 * 3}", 15
  canEvalError "throw 1"
  canEval "{a: 1, b: 2 * 3}", {a: 1, b: 6}
  canEval "[1 2 3 4 ,]", [1, 2, 3, 4]
  canEval "[1, 2, if true then 1 else 2]", [1, 2, 1]
  canEval "try { throw 1 } catch (e) { 2 } finally { 3 }", 2
  s1 = 
    """
    (func count(a) {
      func helper(acc) {
        if (acc > 0)
          helper(acc - 1)
        else
          0
      }
      helper(a)
    })(10)
    """
  canEval s1, 0
  fib = 
    """
    (func fib(n) 
      if (n == 0)
        0
      else if (n <= 2)
        1
      else
        fib(n - 1) + fib(n - 2)
    )(10)
    """
  canEval fib, 55
  fibtco = 
    """
    (func fib(n) {
      func helper(i, acc, next) 
        if i == 0 
          acc
        else 
          helper(i - 1, next, acc + next)
      helper(n, 0, 1)
    })(80)
    """
  canEval fibtco, 23416728348467685
  