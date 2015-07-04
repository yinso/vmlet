anf = require '../src/anf'
AST = require '../src/ast'
SymbolTable = require '../src/symboltable'
assert = require 'assert'
loglet = require 'loglet'
errorlet = require 'errorlet'

describe 'anf test', ->
  
  canTransform = (ast, expected) ->
    it "can transform #{ast}", (done) ->
      try 
        actual = anf.transform ast, new SymbolTable()
        loglet.log '&&&&&&&&&&&&&&&&&&&&&&& ANF transform', ast
        loglet.log actual
        if not (expected == undefined)
          assert.deeEqual actual, expected
        done null
      catch e
        loglet.error e
        done e
  
  canTransform AST.number(1), undefined
  canTransform AST.binary('*', AST.binary('+', AST.number(1), AST.number(2)), AST.number(3)), undefined
  canTransform AST.if(AST.binary('==', AST.string('hello'), AST.string('world')),
      AST.binary('+', 
        AST.number(5), 
        AST.binary('-', 
          AST.number(8), 
          AST.number(11)
        )
      ),
      AST.binary('%', AST.number(10), AST.number(7))
    ), undefined
  canTransform AST.block([ 
        AST.number(1)
        AST.number(2)
        AST.number(10)
        AST.binary('+', 
          AST.number(5), 
          AST.binary('-', 
            AST.number(8), 
            AST.number(11)
          )
        )
      ]
    ), undefined
  
  canTransform AST.define(AST.symbol('foo'),
      AST.binary('+', 
        AST.number(5), 
        AST.binary('-', 
          AST.number(8), 
          AST.number(11)
        )
      )
    ), undefined
  
  canTransform AST.object([
        [
          'foo'
          AST.binary('-', 
            AST.number(8), 
            AST.number(11)
          )
        ]
        [
          'bar'
          AST.number(2)
        ]
      ]
    )
  canTransform AST.array([
        AST.binary('-', 
          AST.number(8), 
          AST.number(11)
        ),
        AST.number(2)
      ]
    )
  canTransform AST.block([
      AST.define(AST.symbol('obj'),
        AST.object([
            [
              'foo'
              AST.binary('-', 
                AST.number(8), 
                AST.number(11)
              )
            ]
            [
              'bar'
              AST.number(2)
            ]
          ]
        )
      ),
      AST.member(AST.symbol('obj'), AST.symbol('foo'))
    ]
  )
  
  canTransform AST.funcall(AST.symbol('isNumber'),
    [
      AST.number(1500)
    ]
  )
  
  canTransform AST.procedure('foo',
    [
      AST.param('a')
      AST.param('b')
    ],
    AST.binary('+', AST.symbol('a'), AST.symbol('b'))
  )
  
  
  