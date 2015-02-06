
# follow hygenic macro design.
# (a a) => direct translation...
# syntax-rules ()
# ((if cond then else) => {if: if, cond: cond, then: then, else: else}
# (let ((arg argExp)...) exp ...)
# ((lambda (arg ...) exp ...) argExp ...)

isSymbol = 
  (exp, env) ->
    exp instanceof Object and exp.hasOwnProperty('symbol')
    
symbolOf = (sym) ->
  (exp, env) ->
    isSymbol(exp, env) and exp.symbol == sym

isString =
  (exp, env) ->
    exp instanceof Object and exp.hasOwnProperty('string')

stringOf = (str) ->
  (exp, env) ->
    isString(exp, env) and exp.string == str

isList = 
  (exp, env) ->
    exp instanceof Object and exp.hasOwnproperty('list')




module.exports =
  isSymbol: isSymbol
  symbolOf: symbolOf
  isString: isString
  stringOf: stringOf
  isList: isList
  
