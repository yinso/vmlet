anf = require '../src/anf'
AST = require '../src/ast'
assert = require 'assert'
loglet = require 'loglet'
errorlet = require 'errorlet'

describe 'anf test', ->
  
  canTransform = (ast, expected) ->
    it "can transform #{ast}", (done) ->
      try 
        actual = anf.transform ast
        loglet.log '&&&&&&&&&&&&&&&&&&&&&&& ANF transform', ast
        loglet.log actual
        if not (expected == undefined)
          assert.deeEqual actual, expected
        done null
      catch e
        loglet.error e
        done e
  
  canTransform AST.make('number', 1), undefined
  canTransform AST.make('binary', '*', AST.make('binary', '+', AST.make('number', 1), AST.make('number', 2)), AST.make('number', 3)), undefined
  canTransform AST.make('if', 
      AST.make('binary', '==', AST.make('string', 'hello'), AST.make('string', 'world')),
      AST.make('binary', '+', 
        AST.make('number', 5), 
        AST.make('binary', '-', 
          AST.make('number', 8), 
          AST.make('number', 11)
        )
      ),
      AST.make('binary', '%', AST.make('number', 10), AST.make('number', 7))
    ), undefined
  canTransform AST.make('block',
      [ 
        AST.make('number', 1)
        AST.make('number', 2)
        AST.make('number', 10)
        AST.make('binary', '+', 
          AST.make('number', 5), 
          AST.make('binary', '-', 
            AST.make('number', 8), 
            AST.make('number', 11)
          )
        )
      ]
    ), undefined
  
  canTransform AST.make('define',
      'foo',
      AST.make('binary', '+', 
        AST.make('number', 5), 
        AST.make('binary', '-', 
          AST.make('number', 8), 
          AST.make('number', 11)
        )
      )
    )
  
  canTransform AST.make('object',
      [
        [
          'foo'
          AST.make('binary', '-', 
            AST.make('number', 8), 
            AST.make('number', 11)
          )
        ]
        [
          'bar'
          AST.make('number', 2)
        ]
      ]
    )
  canTransform AST.make('array',
      [
        AST.make('binary', '-', 
          AST.make('number', 8), 
          AST.make('number', 11)
        ),
        AST.make('number', 2)
      ]
    )
  canTransform AST.make('block',
    [
      AST.make('define', 
        'obj',
        AST.make('object',
          [
            [
              'foo'
              AST.make('binary', '-', 
                AST.make('number', 8), 
                AST.make('number', 11)
              )
            ]
            [
              'bar'
              AST.make('number', 2)
            ]
          ]
        )
      ),
      AST.make('member', AST.make('symbol', 'obj'), AST.make('symbol', 'foo'))
    ]
  )
  
  canTransform AST.make('funcall',
    AST.make('symbol', 'isNumber'),
    [
      AST.make('number', 1500)
    ]
  )
  
  canTransform AST.make('procedure',
    'foo',
    [
      AST.make('param', 'a')
      AST.make('param', 'b')
    ],
    AST.make('binary', '+', AST.make('symbol', 'a'), AST.make('symbol', 'b'))
  )
  
  
  