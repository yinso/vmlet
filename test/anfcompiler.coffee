compiler = require '../src/anfcompiler'
ANF = require '../src/anf'
AST = require '../src/ast'
loglet = require 'loglet'
errorlet = require 'errorlet'

describe 'anf compiler test', ->
  
  canCompile = (ast, expected) ->
    it "can compile ANF from #{ast}", (done) ->
      try 
        loglet.log '~~~~~~~~~~~~~~~ ANF Compile', ast
        anf = ANF.transform ast
        compiled = compiler.compile anf
        loglet.log anf
        loglet.log compiled
        done null
      catch e
        done e
  
  canCompile AST.make('number', 5)
  canCompile AST.make('bool', true)
  canCompile AST.make('string', 'hello world')
  canCompile AST.make('binary', '+', AST.make('number', 10), AST.make('number', 5))
  canCompile AST.make('binary', '*', 
    AST.make('binary', '+', AST.make('number', 10), AST.make('number', 5)), 
    AST.make('number', 5)
  )
  canCompile AST.make('procedure',
    'foo',
    [
      AST.make('param', 'a')
      AST.make('param', 'b')
    ]
    AST.make('binary', '+', AST.make('symbol', 'a'), AST.make('symbol', 'b'))
  )
  canCompile AST.make('funcall', 
    AST.make('symbol', 'isNumber'),
    [
      AST.make('number', 5)
    ]
  )
  canCompile AST.make('object',
    [
      [
        'foo'
        AST.make('number', 1)
      ]
      [
        'bar'
        AST.make('string', 'hello')
      ]
    ]
  )
  canCompile AST.make('member',
    AST.make('object',
      [
        [
          'foo'
          AST.make('number', 1)
        ]
        [
          'bar'
          AST.make('string', 'hello')
        ]
      ]
    ),
    AST.make('symbol', 'foo')
  )
  canCompile AST.make('member',
    AST.make('object',
      [
        [
          'foo'
          AST.make('number', 1)
        ]
        [
          'bar'
          AST.make('string', 'hello')
        ]
      ]
    ),
    AST.make('string', 'foo')
  )
  canCompile AST.make('member',
    AST.make('object',
      [
        [
          'foo'
          AST.make('number', 1)
        ]
        [
          'bar'
          AST.make('string', 'hello')
        ]
      ]
    ),
    AST.make('number', 5)
  )
  canCompile AST.make('if',
    AST.make('binary','==',
      AST.make('number', 5),
      AST.make('number', 10)
    ),
    AST.make('binary', '+', AST.make('number', 10), AST.make('number', 5)), 
    AST.make('binary', '-', AST.make('number', 10), AST.make('number', 5))
  )
  