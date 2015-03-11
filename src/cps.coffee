# reansform from anf to cps
loglet = require 'loglet'
errorlet = require 'errorlet'

ANF = require './anf'
AST = require './ast'
util = require './util'

types = {}

register = (ast, cps) ->
  if types.hasOwnProperty(ast.type)
    throw errorlet.create {error: 'CPS.duplicate_ast_type', type: ast.type}
  else
    types[ast.type] = cps
  
get = (ast) ->
  if types.hasOwnProperty(ast.type())
    types[ast.type()]
  else
    throw errorlet.create {error: 'CPS.unsupported_as_type', type: ast}

override = (ast, cps) ->
  types[ast.type] = cps

###

CPS occurs with a funcall being async.

res = foo(a, b, c)
bar...
baz...
==> 
  
return _rt.tail(foo, a, b, c, function (err, res) {
  if (err) {
    return _rt.tail(cb, err);
  } else {
    bar...
    baz...
  }
  })

The above shows that "bar... baz..." is the continuation of the funcall foo(a, b,, c), and if CPS'd it gets
translated into the else branch of the callback. Note that res is the result from the function itslef, and 
we have previously no reference to err symbol (unless we happen to be within a try catch block as well)

Note that we might have to also compile backwards, so we successively generate the intermediate functions.
  
Also note that we might not necessarily know whether a function is sync/async (we should know if the function is 
  previously created, but we might not know about functions yet to be created, and some functions might be ambiguous)...

In a way - the current design is still ambiguous...
  
In an if expression, CPS can occur for COND. Since ANF already get the expression separated, it's trivial in this case
for the CPS.

return _rt.tail(cond, ..., function(err, res) {
  if (err) {
    return _rt.tail(cb, err);
  } else {
    // this part is the original if expression.
    if (res) {
      //... the original then block
    } else {
      // ... the original else block...
    }
  }
})

Ambiguous can be difficult... but the idea is that we have the if expression (outside of the cond expression) being
named as a block with the appropriate closure (block will be treated as a function as well).

if a() { b c } else { d e }

a$1 = a()
block_if = function () {
  if (a$1) {
    b c
  } else {
    d e
  }
}
block_if()

it turns out that in order to deal with async in a transparent level - we will need to have the ability to TYPE
the expression (this is so that we can infer whether or not a particular value will be async).

That means until we can do so, we are stuck with one of the approaches...



###


cps = (anf, contAST = AST.make('symbol', '_done'), cbAST = contAST) ->
  # the idea is that the last statement is the one that we want to return? 
  # so if we push the return function in like this... what would happen? 
  # {NUMBER 1}
  # =>
  # {ANF {RETURN NUMBER 1}}
  # => 
  # {ANF {RETURN {FUNCALL {SYMBOL CB} {NULL} {NUMBER 1}}}}
  # 
  # when compile the return function -> 
  ast = AST.make('task', undefined,
    [ AST.make('param', '_rt')]
    , anf
  )
  _cpsOne ast, contAST, cbAST
  
cpsBlock = (anf, contAST, cbAST) ->
  for i in [anf.items.length - 1 ..0] by -1
    contAST = _cpsOne anf.items[i], contAST, cbAST
  normalize contAST

register AST.get('block'), cpsBlock
register AST.get('anf'), cpsBlock

_cpsOne = (item, contAST, cbAST) ->
  loglet.log '_cpsOne', item, contAST, cbAST
  cpser = get item
  cpser item, contAST, cbAST

cpsTaskcall = (ast, contAST, cbAST) ->
  args = [].concat(ast.args)
  if contAST.type() == 'procedure'
    args.push contAST
  else
    args.push makeCallback contAST, cbAST
  AST.make('return', AST.make('funcall', ast.funcall, args))

register AST.get('taskcall'), cpsTaskcall

cpsTask = (ast, contAST, cbAST) ->
  # the idea of cpsing task is that we want to cps the body.
  cbAST = AST.make('symbol', '_done')
  body = normalize ast.body
  params = [].concat(ast.params).concat(cbAST)
  AST.make('procedure',
    ast.name,
    params,
    _cpsOne(body, cbAST, cbAST)
  )
  
register AST.get('task'), cpsTask

combine = (ast, contAST) ->
  if not contAST
    ast
  else if ANF.isANF(contAST)
    contAST.items.unshift ast
    contAST
  else
    new ANF.ANF [ ast, contAST ]

concat = (ast1, ast2) ->
  is1anf = ANF.isANF(ast1)
  is2anf = ANF.isANF(ast2)
  loglet.log 'concat', ast1, ast2, is1anf, is2anf
  if is1anf
    new ANF.ANF ast1.items.concat(if is2anf then ast2.items else [ ast2 ])
  else
    new ANF.ANF [ ast1 ].concat(if is2anf then ast2.items else [ ast2 ])

normalize = (ast) ->
  if ANF.isANF(ast)
    ast
  else
    new ANF.ANF [ ast ]

makeCallback = (contAST, cbAST, resParam = AST.make('param', 'res')) ->
  if contAST == cbAST
    contAST
  else
    # this part needs to be ANF-ized...
    AST.make('procedure', undefined,
      [
        AST.make('param', 'err')
        resParam
      ],
      AST.make('if',
        AST.make('symbol', 'err'),
        AST.make('return', AST.make('funcall', cbAST, [ AST.make('symbol', 'err') ])),
        contAST
      )
    )

makeCpsDef = (type) ->
  (ast, contAST, cbAST) ->
    loglet.log "--cps.#{type}", ast, contAST
    if ast.isAsync()
      _cpsOne ast.val, makeCallback(contAST, cbAST, AST.make('param', ast.name)), cbAST
    else
      head = AST.make(type, 
        ast.name,
        _cpsOne(ast.val, null, null)
      )
      combine head, contAST
    
cpsTempvar = makeCpsDef('tempvar')

register AST.get('tempvar'), cpsTempvar

cpsDefine = makeCpsDef('define')

register AST.get('define'), cpsDefine

cpsReturn = (ast, contAST, cbAST) ->
  #type = exp.type() # for dealing with none 
  loglet.log 'cpsReturn', ast, contAST
  val = ast.val
  if val.type() == 'taskcall'
    cpsTaskcall val, contAST, cbAST
  #else if val.type() == 'task'
    # the idea here is that we want to compile a single value...
  else
    AST.make('return',
      AST.make('funcall',
        cbAST,
        [ 
          AST.make('null')
          _cpsOne(val, null, null)
          # I need a way to deal with there isn't anything at the end...
        ]
      )
    )

register AST.get('return'), cpsReturn

cpsIf = (ast, contAST, cbAST) ->
  loglet.log 'cpsIf', ast
  AST.make('if',
    ast.if,
    _cpsOne(ast.then, contAST, cbAST),
    _cpsOne(ast.else, contAST, cbAST)
  )

register AST.get('if'), cpsIf

cpsScalar = (ast, contAST, cbAST) ->
  combine ast, contAST

register AST.get('number'), cpsScalar
register AST.get('bool'), cpsScalar
register AST.get('null'), cpsScalar
register AST.get('symbol'), cpsScalar
register AST.get('string'), cpsScalar
register AST.get('binary'), cpsScalar
register AST.get('member'), cpsScalar
register AST.get('procedure'), cpsScalar
register AST.get('proxyval'), cpsScalar
register AST.get('ref'), cpsScalar
register AST.get('funcall'), cpsScalar
register AST.get('array'), cpsScalar
register AST.get('object'), cpsScalar

# this is not the way it should have worked... what the heck...!
cpsThrow = (ast, contAST, cbAST) ->
  AST.make 'return', AST.make('funcall', cbAST, [ ast.val ])

register AST.get('throw'), cpsThrow

makeErrorHandler = (catchExp, finallyExp, cbAST, name) ->
  loglet.log 'cps.makeErrorHandler', catchExp.body, finallyExp.body, cbAST
  body = concat finallyExp.body, catchExp.body
  body = _cpsOne body, cbAST, cbAST
  AST.make 'tempvar', name, AST.make('procedure', undefined, [ catchExp.param ], body)

cpsTry = (ast, contAST, cbAST) ->
  name = '__handleError$1'
  errorAST = makeErrorHandler ast.catches[0], ast.finally, cbAST, name
  cbAST = AST.make 'ref', name
  bodyAST = _cpsOne ast.body, contAST, cbAST
  combine errorAST, bodyAST

register AST.get('try'), cpsTry

cpsCatch = (ast, contAST, cbAST) ->
  body = _cpsOne ast.body, contAST, cbAST
  AST.make 'catch', ast.param, body

register AST.get('catch'), cpsCatch

module.exports = 
  register: register
  get: get
  override: override
  transform: cps


