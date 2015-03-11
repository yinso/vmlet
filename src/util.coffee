isFunction = (func) ->
  typeof(func) == 'function' or func instanceof Function

isAsync = (func) ->
  isFunction(func) and func.__vmlet?.async

isSync = (func) ->
  isFunction(func) and not (func.__vmlet.async)

module.exports = 
  isFunction: isFunction
  isAsync: isAsync
  isSync: isSync
  