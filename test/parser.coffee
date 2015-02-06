parser = require '../src/parser'
assert = require 'assert'
AST = require '../src/ast'
loglet = require 'loglet'

describe 'parser test', ->
  
  canParse = (stmt, expected) ->
    it "can parse #{stmt}", (done) ->
      try 
        actual = parser.parse stmt
        assert.deepEqual actual, expected
        done null
      catch e 
        loglet.log "************** ERROR: parsing #{stmt}"
        loglet.log expected
        loglet.log actual
        loglet.error e
        done e
  
  canParse "1", AST.make('number', 1)
  canParse "1.5", AST.make('number', 1.5)
  canParse "-10.21", AST.make('number', -10.21)
  canParse "true", AST.make('bool', true)
  canParse "false", AST.make('bool', false)
  canParse "null", AST.make('null', null)
  canParse "1 * 3", AST.make('binary', '*', AST.make('number', 1), AST.make('number', 3))
  canParse "1 * 3 / 6", AST.make('binary', '/', AST.make('binary', '*', AST.make('number', 1), AST.make('number', 3)), AST.make('number', 6))
  canParse "1 + 2 * 3 - 4", AST.make('binary',
    '-',
    AST.make('binary', 
      '+',
      AST.make('number', 1), 
      AST.make('binary', '*', AST.make('number', 2), AST.make('number', 3))
    ),
    AST.make('number', 4)
  )
  canParse "1 + 2 == 4 - 1",
    AST.make('binary'
      '==',
      AST.make('binary', 
        '+',
        AST.make('number', 1)
        AST.make('number', 2)
      ), 
      AST.make('binary',
        '-',
        AST.make('number', 4),
        AST.make('number', 1)
      )
    )
  canParse "1 != 2 and 3 < 4",
    AST.make('binary',
      'and',
      AST.make('binary', 
        '!=',
        AST.make('number', 1),
        AST.make('number', 2)
      ),
      AST.make('binary',
        '<',
        AST.make('number', 3),
        AST.make('number', 4)
      )
    )
  canParse "1 > 2 or 3 < 4",
    AST.make('binary',
      'or',
      AST.make('binary',
        '>',
        AST.make('number', 1),
        AST.make('number', 2)
      ),
      AST.make('binary',
        '<',
        AST.make('number', 3),
        AST.make('number', 4)
      )
    )
  canParse "if 1 { 2 } else { 3 }", AST.make('if', AST.make('number', 1), AST.make('number', 2), AST.make('number', 3))
  canParse "{ 1 2 3 }", AST.make 'block', [ AST.make('number', 1), AST.make('number', 2), AST.make('number', 3)]
  canParse "{ 1 }", AST.make 'number', 1
  canParse "{abc: 1}", AST.make 'object', [ ['abc', AST.make('number', 1)] ]
  canParse "[1 2 3 ]", AST.make 'array', [ AST.make('number', 1), AST.make('number', 2), AST.make('number', 3) ]
  canParse "define x = 1", AST.make('define', 'x', AST.make('number', 1))
  canParse "[1 2 3][1]", 
    AST.make 'member',
      AST.make('array',
        [
          AST.make('number', 1)
          AST.make('number', 2)
          AST.make('number', 3)
        ]
      ),
      AST.make('number', 1)
  canParse "[1 , 2 ,  3 , ].hello(2)",
    AST.make 'funcall',
      AST.make('member', 
        AST.make('array',
          [
            AST.make('number', 1)
            AST.make('number', 2)
            AST.make('number', 3)
          ]
        ),
        AST.make('symbol', 'hello')
      ), 
      [ AST.make('number', 2) ]
  canParse "function add(a, b) a + b", 
    AST.make 'proc',
      'add',
      [
        AST.make('param', 'a')
        AST.make('param', 'b') 
      ],
      AST.make('binary',
        '+',
        AST.make('symbol', 'a'),
        AST.make('symbol', 'b')
      )
  canParse "func (a, b) { a + b }", 
    AST.make 'proc',
      null,
      [
        AST.make('param', 'a')
        AST.make('param', 'b') 
      ],
      AST.make('binary',
        '+',
        AST.make('symbol', 'a'),
        AST.make('symbol', 'b')
      )
  canParse 'throw 1 + 2',
    AST.make 'throw',
      AST.make 'binary',
        '+',
        AST.make('number', 1),
        AST.make('number', 2)
  canParse 'try { throw 1 } catch (e) { 2 } finally { 3 }',
    AST.make 'try',
      AST.make('throw',
        AST.make('number', 1)
      ),
      [
        AST.make('catch',
          AST.make('param', 'e'),
          AST.make('number', 2)
        )
      ],
      AST.make('finally', AST.make('number', 3))
  
  
  