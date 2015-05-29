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
  
  canCompile AST.number(5)
  canCompile AST.bool(true)
  canCompile AST.string('hello world')
  canCompile AST.binary('+', AST.number(10), AST.number(5))
  canCompile AST.binary('*', 
    AST.binary('+', AST.number(10), AST.number(5)), 
    AST.number(5)
  )
  canCompile AST.procedure('foo',
    [
      AST.param('a')
      AST.param('b')
    ]
    AST.binary('+', AST.symbol('a'), AST.symbol('b'))
  )
  canCompile AST.funcall(AST.symbol('isNumber'),
    [
      AST.number(5)
    ]
  )
  canCompile AST.object([
      [
        'foo'
        AST.number(1)
      ]
      [
        'bar'
        AST.string('hello')
      ]
    ]
  )
  canCompile AST.member(AST.object([
        [
          'foo'
          AST.number(1)
        ]
        [
          'bar'
          AST.string('hello')
        ]
      ]
    ),
    AST.symbol('foo')
  )
  canCompile AST.member(AST.object([
        [
          'foo'
          AST.number(1)
        ]
        [
          'bar'
          AST.string('hello')
        ]
      ]
    ),
    AST.string('foo')
  )
  canCompile AST.member(AST.object([
        [
          'foo'
          AST.number(1)
        ]
        [
          'bar'
          AST.string('hello')
        ]
      ]
    ),
    AST.number(5)
  )
  canCompile AST.if(AST.binary('==',
      AST.number(5),
      AST.number(10)
    ),
    AST.binary('+', AST.number(10), AST.number(5)), 
    AST.binary('-', AST.number(10), AST.number(5))
  )
  