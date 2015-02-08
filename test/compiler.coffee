compiler = require '../src/compiler'
baseEnv = require '../src/baseenv'
Environment = require '../src/environment'
AST = require '../src/ast'
loglet = require 'loglet'
assert = require 'assert'
CodeBlock = require '../src/codeblock'
Procedure = require '../src/procedure'
Task = require '../src/task'

describe 'compiler test', () ->
  
  addFunc = baseEnv.get '+'
  
  canCompile  = (ast, expected) ->
    it "can compile #{ast}", (done) ->
      try 
        actual = compiler.compile ast
        if expected != undefined
          assert expected.equals(actual)
        done null
      catch e
        loglet.log '------------- ERROR: cannot compile', ast
        loglet.log 'expected = ', expected
        loglet.log 'actual = ', actual
        loglet.error e
        done e
  
  canCompile AST.make('number', 1), 
    new CodeBlock().push(1)

  canCompile AST.make('block', 
    [
      AST.make('number', 1)
      AST.make('number', 2)
      AST.make('number', 3)
    ]), 
    new CodeBlock()
      .push(1)
      .push(2)
      .push(3)
  
  ###
  _v1 = true
  if (_v1)
    return 1
  else
    return 2
  ###
  
  canCompile AST.make('if', AST.make('bool', true), AST.make('number', 1), AST.make('number', 2)), 
    new CodeBlock()
      .push(true)
      .ifOrJump(2)
      .push(1)
      .jump(1)
      .push(2)
  
  ###
  # we might need a way to handle return... 
  # to make things uniform...
  _v1 = 1
  _v2 = 2
  _v3 = addFunc(_v1, _v2)
  if _v3 instanceof Promise
    _v3.then (val) ->
      .else (err) ->
      
  vm.then () ->
    
  ###
  canCompile AST.make('funcall', AST.make('symbol', '+'), [ AST.make('number', 1), AST.make('number', 2)]), 
    new CodeBlock()
      .push(1)
      .push(2)
      .push(addFunc)
      .funcall(2)
  
  canCompile AST.make('define', 'test', AST.make('number', 5)), 
    new CodeBlock()
      .push(5)
      .define('test')
      
  canCompile AST.make('procedure', 'add', 
      [
        AST.make('param', 'a')
        AST.make('param', 'b')
      ],
      AST.make 'binary', '+', AST.make('symbol', 'a'), AST.make('symbol', 'b')
    ), 
    new CodeBlock()
      .push(
        new Procedure('add',
          Procedure.makeParams([
            Procedure.makeParam('a'),
            Procedure.makeParam('b')
          ]),
          new CodeBlock()
            .ref('a')
            .ref('b')
            .plus()
        )
      )
  
  canCompile AST.make('catch',
      AST.make('param', 'err'), 
      AST.make('block', 
        [
          AST.make('symbol', 'err')
        ]
      )
    ), 
    new CodeBlock()
      .ifErrorOrJump(5)
      .pushEnv()
      .push(Procedure.makeParam('err'))
      .bindErrorOrJump(1)
      .ref('err') 
      .popEnv()
  
  canCompile AST.make('finally', 
      AST.make('block', [
        AST.make('number', 5)
      ])
    ), 
    new CodeBlock()
      .finally()
      .push(5)
      .endFinally()
      
  canCompile AST.make('try',
      AST.make('block',
        [
          AST.make('throw', AST.make('number', 10))
          AST.make('string', 'hello')
        ]
      ),
      [
        AST.make('catch', AST.make('param', 'err'), AST.make('number', 5))
      ],
      AST.make('finally', AST.make('number', 1))
    ),
    undefined
  
  canCompile AST.make('try',
      AST.make('block',
        [
          AST.make('throw', AST.make('number', 10))
          AST.make('string', 'hello')
        ]
      ),
      [
        # no catch
      ],
      AST.make('finally', AST.make('number', 1))
    ),
    undefined

  canCompile AST.make('try',
      AST.make('block',
        [
          AST.make('throw', AST.make('number', 10))
          AST.make('string', 'hello')
        ]
      ),
      [
        AST.make('catch', AST.make('param', 'err'), AST.make('number', 5))
      ],
      null
    ),
    undefined
  