# reansform from anf to cps
loglet = require 'loglet'
errorlet = require 'errorlet'

AST = require './ast'
util = require './util'
TR = require './trace'

###
There are basically two types we need to handle the CPS conversion for: TASK and TOPLEVEL.

The idea is simple. We add an implicit callback parameter, as well as continuation call for both regular and error 
conditions. 

TOPLEVE { exp exp2 ... expLast } 
=> 
function (_done) { 
  try {
    exp exp2 ... 
    return _done(null, expLast); // whatever expLast evaluates to.
  } catch (e) {
    return _done(e);
  }
}

TASK(arg, ...) {
  exp ... expLast
}
=> 
_rt.task(function (arg, ..., _done) {
  try {
    exp ... 
    return _done(null, expLast); 
  } catch (e) {
    return _done(e);
  }
});

###
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

class CpsTransformer 
  @transform: (ast) -> 
    if not @reg 
      @reg = new @()
    @reg.transform ast 
  transform: TR.trace('CPS.transform', (ast) -> 
    res = 
      switch ast.type()
        when 'task'
          @_task ast 
        when 'toplevel', 'module'
          @_toplevel ast 
        else
          throw new Error("CPS:unsupported_toplevel: #{ast}")
    res
    )
  run: (ast, contAST, cbAST) ->
    type = "_#{ast.type()}"
    if @[type]
      @[type] ast, contAST, cbAST
    else
      throw new Error("CPS:unknown_ast_type: #{ast.type()}")
  normalize: (ast) -> 
    if ast.type() == 'block'
      ast
    else
      AST.block [ ast ]
  combine: (ast, contAST) ->
    if not contAST
      ast
    else if contAST.type() == 'block'
      AST.block [ ast ].concat(contAST.items)
    else
      AST.block [ ast, contAST ]
  concat: (ast1, ast2) ->
    is1anf = ast1.type() == 'block'
    is2anf = ast2.type() == 'block'
    if is1anf
      AST.block ast1.items.concat(if is2anf then ast2.items else [ ast2 ])
    else
      AST.block [ ast1 ].concat(if is2anf then ast2.items else [ ast2 ])
  makeCallback: (contAST, cbAST, resParam = AST.param(AST.symbol('res'))) ->
    err = AST.symbol('err')
    if contAST == cbAST
      contAST
    else
      # this part needs to be ANF-ized...
      AST.procedure(undefined,
        [
          AST.param(err)
          resParam
        ],
        AST.block([AST.if(err,
          AST.return(AST.funcall(cbAST, [ err ])),
          contAST
        )])
      )
  _toplevel: (ast) ->
    body = @normalize ast.body 
    #console.log 'cps.toplevel', ast.body, body
    params = [ ast.moduleParam ]
    cbAST = ast.callbackParam.ref()
    task = @_task AST.task(null, params, body), cbAST, cbAST
    ast.clone task.body
  _task: (ast, contAST, cbAST) ->
    body = @normalize ast.body
    params = [].concat(ast.params).concat(ast.callbackParam)
    #console.log '--cpTask', ast.body, body
    body = 
      if body.items[0].type() == 'try'
          @run(body, cbAST, cbAST)
      else
        AST.try(
          @run(body, cbAST, cbAST), 
          [ 
            AST.catch(
              ast.errorParam, 
              AST.block(
                [
                  AST.return(AST.funcall(
                    cbAST, 
                    [ 
                      ast.errorParam.ref()
                    ]))
                ]
              )
            )
          ], 
          null
        )
    AST.procedure(
      ast.name,
      params,
      AST.block(
        [
          body
        ]
      )
    )
  _block: (anf, contAST, cbAST) ->
    for i in [anf.items.length - 1 ..0] by -1
      contAST = @run anf.items[i], contAST, cbAST
    @normalize contAST
  _taskcall: (ast, contAST, cbAST) ->
    args = [].concat(ast.args)
    # console.log '--_taskcall', ast, contAST, cbAST
    if contAST.type() == 'procedure'
      args.push contAST
    else
      args.push @makeCallback contAST, cbAST
    AST.return(AST.funcall(ast.funcall, args))
  _local: (ast, contAST, cbAST) ->
    TR.log "--cps.local", ast, contAST
    if ast.isAsync()
      @run ast.value, @makeCallback(contAST, cbAST, AST.param(ast.name)), cbAST
    else
      #head = AST.local ast.name, _cpsOne(ast.value, null, null)
      @combine ast, contAST
  _assign: (ast, contAST, cbAST) ->
    #TR.log "--cps.assign", ast, contAST
    if ast.isAsync()
      @run ast.value, @makeCallback(contAST, cbAST, AST.param(ast.name)), cbAST
    else
      head = AST.assign ast.name, @run(ast.value, null, null)
      @combine head, contAST
  _define: (ast, contAST, cbAST) ->
    #console.log "--cps.#{type}", ast, ast.isAsync(), contAST, cbAST
    if ast.isAsync()
      param = AST.param ast.name.clone()
      contAST = @combine AST.define(ast.name, param.name), contAST
      @run ast.value, @makeCallback(contAST, cbAST, param), cbAST
    else
      head = AST.make('define', 
        ast.name,
        @run(ast.value, null, null)
      )
      @combine head, contAST
  _return: (ast, contAST, cbAST) ->
    #type = exp.type() # for dealing with none 
    #TR.log '--cps.return', ast, contAST
    val = ast.value
    if val.type() == 'taskcall'
      @_taskcall val, contAST, cbAST
    #else if val.type() == 'task'
      # the idea here is that we want to compile a single value...
    else
      AST.return(AST.funcall(cbAST,
          [ 
            AST.make('null')
            @run(val, null, null)
            # I need a way to deal with there isn't anything at the end...
          ]
        )
      )
  _if: (ast, contAST, cbAST) ->
    AST.if(ast.cond,
      @run(ast.then, contAST, cbAST),
      @run(ast.else, contAST, cbAST)
    )
  _number: (ast, contAST, cbAST) ->
    @combine ast, contAST
  _string: (ast, contAST, cbAST) ->
    @combine ast, contAST
  _bool: (ast, contAST, cbAST) ->
    @combine ast, contAST
  _null: (ast, contAST, cbAST) ->
    @combine ast, contAST
  _unit: (ast, contAST, cbAST) ->
    @combine ast, contAST
  _symbol: (ast, contAST, cbAST) ->
    @combine ast, contAST
  _binary: (ast, contAST, cbAST) ->
    @combine ast, contAST
  _procedure: (ast, contAST, cbAST) ->
    @combine ast, contAST
  _member: (ast, contAST, cbAST) ->
    @combine ast, contAST
  _ref: (ast, contAST, cbAST) ->
    @combine ast, contAST
  _proxyval: (ast, contAST, cbAST) ->
    @combine ast, contAST
  _var: (ast, contAST, cbAST) ->
    @combine ast, contAST
  _funcall: (ast, contAST, cbAST) ->
    @combine ast, contAST
  _array: (ast, contAST, cbAST) ->
    @combine ast, contAST
  _object: (ast, contAST, cbAST) ->
    @combine ast, contAST
  _import: (ast, contAST, cbAST) ->
    @combine ast, contAST
  _export: (ast, contAST, cbAST) ->
    @combine ast, contAST
  _throw: (ast, contAST, cbAST) ->
    AST.return AST.funcall(cbAST, [ ast.value ])
  makeErrorHandler: (catchExp, finallyExp, cbAST, name) ->
    # console.log '--cps.makeErrorHandler', catchExp?.body, finallyExp?.body, cbAST
    catchBody = @run catchExp.body, cbAST, cbAST
    errParam = catchExp.param
    resParam = AST.param(AST.symbol('res'))
    okReturnExp = AST.return(AST.funcall(cbAST, [ errParam.name , resParam.name ]))
    errorBody = 
      if finallyExp 
        AST.try(
          @run(finallyExp.body, catchBody, catchBody)
          [ 
            AST.catch(
              errParam,
              AST.block([
                okReturnExp 
              ])
            )
          ]
        )
      else
        catchBody 
    body = 
      AST.block([
        AST.if(
          errParam.name
          errorBody
          okReturnExp
        )
      ])
    AST.local name, AST.procedure(undefined, [ catchExp.param , resParam ], body)
  _try: (ast, contAST, cbAST) ->
    name = AST.symbol('__handleError', 1)
    # console.log '--_try', ast.catches[0], ast.finally
    catchExp = 
      if ast.catches.length > 0
        ast.catches[0]
      else
        # this thing creates a new parameter... we need a way to create parameters without 
        # having the parameter being global... 
        AST.catch()
    errorAST = @makeErrorHandler catchExp, ast.finally, cbAST, name
    cbAST = name
    bodyAST = @run ast.body, contAST, cbAST
    tryBody = @combine errorAST, bodyAST 
    finalCatch = AST.catch()
    finalCatch.body = AST.block [
        AST.return(AST.funcall(errorAST.name, [ finalCatch.param.name ]))
      ]
    AST.try(
      tryBody
      [ 
        finalCatch
      ]
    )
  _catch: (ast, contAST, cbAST) ->
    body = @run ast.body, contAST, cbAST
    AST.catch ast.param, body

module.exports = CpsTransformer

###
#

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

cps = (ast) ->
  res = 
    switch ast.type()
      when 'task'
        _task ast
      when 'toplevel', 'module'
        _toplevel ast
      else # this should error!
        throw new Error("CPS:unsupported_toplevel_type: #{ast}")
  res

_cpsOne = (item, contAST, cbAST) ->
  cpser = get item
  cpser item, contAST, cbAST

_toplevel = (ast) ->
  body = normalize ast.body 
  #console.log 'cps.toplevel', ast.body, body
  params = [ ast.moduleParam ]
  cbAST = ast.callbackParam.ref()
  task = _task AST.task(null, params, body), cbAST, cbAST
  ast.clone task.body

register AST.get('toplevel'), _toplevel

_task = (ast, contAST, cbAST) ->
  body = normalize ast.body
  params = [].concat(ast.params).concat(ast.callbackParam)
  #console.log '--cpTask', ast.body, body
  body = 
    if body.items[0].type() == 'try'
        _cpsOne(body, cbAST, cbAST)
    else
      AST.try(
        _cpsOne(body, cbAST, cbAST), 
        [ 
          AST.catch(
            ast.errorParam, 
            AST.block(
              [
                AST.return(AST.funcall(
                  cbAST, 
                  [ 
                    ast.errorParam.ref()
                  ]))
              ]
            )
          )
        ], 
        null
      )
  AST.procedure(
    ast.name,
    params,
    AST.block(
      [
        body
      ]
    )
  )
  
register AST.get('task'), _task

_block = (anf, contAST, cbAST) ->
  for i in [anf.items.length - 1 ..0] by -1
    contAST = _cpsOne anf.items[i], contAST, cbAST
  normalize contAST

register AST.get('block'), _block

_taskcall = (ast, contAST, cbAST) ->
  args = [].concat(ast.args)
  # console.log '--_taskcall', ast, contAST, cbAST
  if contAST.type() == 'procedure'
    args.push contAST
  else
    args.push makeCallback contAST, cbAST
  AST.return(AST.funcall(ast.funcall, args))

register AST.get('taskcall'), _taskcall

combine = (ast, contAST) ->
  if not contAST
    ast
  else if contAST.type() == 'block'
    AST.block [ ast ].concat(contAST.items)
    #contAST.items.unshift ast
    #contAST
  else
    AST.block [ ast, contAST ]

concat = (ast1, ast2) ->
  is1anf = ast1.type() == 'block'
  is2anf = ast2.type() == 'block'
  if is1anf
    AST.block ast1.items.concat(if is2anf then ast2.items else [ ast2 ])
  else
    AST.block [ ast1 ].concat(if is2anf then ast2.items else [ ast2 ])

normalize = (ast) ->
  if ast.type() == 'block'
    ast
  else
    AST.block [ ast ]

makeCallback = (contAST, cbAST, resParam = AST.param('res')) ->
  err = AST.symbol('err')
  # console.log '--makeCallback', contAST, cbAST, resParam
  if contAST == cbAST
    contAST
  else
    # this part needs to be ANF-ized...
    AST.procedure(undefined,
      [
        AST.param(err)
        resParam
      ],
      AST.block([AST.if(err,
        AST.return(AST.funcall(cbAST, [ err ])),
        contAST
      )])
    )

_local = (ast, contAST, cbAST) ->
  #TR.log "--cps.local", ast, contAST
  if ast.isAsync()
    _cpsOne ast.value, makeCallback(contAST, cbAST, AST.param(ast.name)), cbAST
  else
    #head = AST.local ast.name, _cpsOne(ast.value, null, null)
    combine ast, contAST

register AST.get('local'), _local

_assign = (ast, contAST, cbAST) ->
  #TR.log "--cps.assign", ast, contAST
  if ast.isAsync()
    _cpsOne ast.value, makeCallback(contAST, cbAST, AST.param(ast.name)), cbAST
  else
    head = AST.assign ast.name, _cpsOne(ast.value, null, null)
    combine head, contAST

register AST.get('assign'), _assign

makeCpsDef = (type) ->
  (ast, contAST, cbAST) ->
    #console.log "--cps.#{type}", ast, ast.isAsync(), contAST, cbAST
    if ast.isAsync()
      param = AST.param ast.name.clone()
      contAST = combine AST.define(ast.name, param.name), contAST
      _cpsOne ast.value, makeCallback(contAST, cbAST, param), cbAST
    else
      head = AST.make(type, 
        ast.name,
        _cpsOne(ast.value, null, null)
      )
      combine head, contAST

_define = makeCpsDef('define')
register AST.get('define'), _define

_return = (ast, contAST, cbAST) ->
  #type = exp.type() # for dealing with none 
  #TR.log '--cps.return', ast, contAST
  val = ast.value
  if val.type() == 'taskcall'
    _taskcall val, contAST, cbAST
  #else if val.type() == 'task'
    # the idea here is that we want to compile a single value...
  else
    AST.return(AST.funcall(cbAST,
        [ 
          AST.make('null')
          _cpsOne(val, null, null)
          # I need a way to deal with there isn't anything at the end...
        ]
      )
    )

register AST.get('return'), _return

_if = (ast, contAST, cbAST) ->
  AST.if(ast.cond,
    _cpsOne(ast.then, contAST, cbAST),
    _cpsOne(ast.else, contAST, cbAST)
  )

register AST.get('if'), _if

_scalar = (ast, contAST, cbAST) ->
  combine ast, contAST

register AST.get('number'), _scalar
register AST.get('bool'), _scalar
register AST.get('null'), _scalar
register AST.get('symbol'), _scalar
register AST.get('string'), _scalar
register AST.get('binary'), _scalar
register AST.get('member'), _scalar
register AST.get('procedure'), _scalar
register AST.get('ref'), _scalar
register AST.get('proxyval'), _scalar
register AST.get('var'), _scalar
register AST.get('funcall'), _scalar
register AST.get('array'), _scalar
register AST.get('object'), _scalar
register AST.get('unit'), _scalar
register AST.get('import'), _scalar
register AST.get('export'), _scalar

_throw = (ast, contAST, cbAST) ->
  AST.return AST.funcall(cbAST, [ ast.value ])

register AST.get('throw'), _throw

_makeErrorHandler = (catchExp, finallyExp, cbAST, name) ->
  # console.log '--cps.makeErrorHandler', catchExp?.body, finallyExp?.body, cbAST
  catchBody = _cpsOne catchExp.body, cbAST, cbAST
  errParam = catchExp.param
  resParam = AST.param(AST.symbol('res'))
  okReturnExp = AST.return(AST.funcall(cbAST, [ errParam.name , resParam.name ]))
  errorBody = 
    if finallyExp 
      AST.try(
        _cpsOne(finallyExp.body, catchBody, catchBody)
        [ 
          AST.catch(
            errParam,
            AST.block([
              okReturnExp 
            ])
          )
        ]
      )
    else
      catchBody 
  body = 
    AST.block([
      AST.if(
        errParam.name
        errorBody
        okReturnExp
      )
    ])
  AST.local name, AST.procedure(undefined, [ catchExp.param , resParam ], body)

_try = (ast, contAST, cbAST) ->
  name = AST.symbol('__handleError', 1)
  # console.log '--_try', ast.catches[0], ast.finally
  catchExp = 
    if ast.catches.length > 0
      ast.catches[0]
    else
      # this thing creates a new parameter... we need a way to create parameters without 
      # having the parameter being global... 
      AST.catch()
  errorAST = _makeErrorHandler catchExp, ast.finally, cbAST, name
  cbAST = name
  bodyAST = _cpsOne ast.body, contAST, cbAST
  tryBody = combine errorAST, bodyAST 
  finalCatch = AST.catch()
  finalCatch.body = AST.block [
      AST.return(AST.funcall(errorAST.name, [ finalCatch.param.name ]))
    ]
  AST.try(
    tryBody
    [ 
      finalCatch
    ]
  )

register AST.get('try'), _try

_catch = (ast, contAST, cbAST) ->
  body = _cpsOne ast.body, contAST, cbAST
  AST.catch ast.param, body

register AST.get('catch'), _catch

module.exports = 
  register: register
  get: get
  override: override
  transform: cps

####
