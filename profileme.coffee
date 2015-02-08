
VM = require './src/vm'
loglet = require 'loglet'
seqNum = parseInt(require('yargs').demand(1).argv._[0])
funclet = require 'funclet'
errorlet = require 'errorlet'

fib = (n) ->
  if n <= 0
    0
  else if n <= 2
    1
  else 
    fib(n - 1) + fib(n - 2)

baseline = (cb) ->
  timerKey = 'fib.baseLine'
  console.time timerKey
  res = fib seqNum
  console.timeEnd timerKey
  console.log res
  cb null

vm = new VM()

vmScript = (cb) ->
  timerKey = 'vm.script'
  script = 
    """
    define fib = func fib(n)
      if n <= 0
        0
      else if n <= 2
        1
      else
        fib(n - 1) + fib(n - 2)
    """
  funclet
    .start (next) ->
      loglet.log timerKey
      vm.eval script, next
    .then (val, next) ->
      console.time timerKey
      vm.eval "fib(#{seqNum})", next
    .catch (err) ->
      console.timeEnd timerKey
      cb err
    .done (res) ->
      console.timeEnd timerKey
      loglet.log res
      cb null

vmInternal = (cb) ->
  timerKey = 'interpreter.built-in'
  funclet
    .start (next) ->
      console.time timerKey
      vm.eval "fib2(#{seqNum})", next
    .catch (err) ->
      console.timeEnd timerKey
      cb err
    .done (res) ->
      console.timeEnd timerKey
      loglet.log res
      cb null

promiseBased = (promiseMod,cb) ->
  timerKey = "fib.async.promise.#{promiseMod}"
  Promise = require promiseMod
  fibAsync2 = (n) ->
    p = new Promise (ok, fail) ->
      if n <= 0
        ok 0
      else if n <= 2
        ok 1
      else 
        n_1 = null
        n_2 = null
        fibAsync2(n - 1)
          .then (v) ->
            n_1 = v
            fibAsync2(n - 2)
          .then (v) ->
            n_2 = v 
            ok n_1 + n_2
          .catch (e) -> fail e
    p
  funclet
    .start (next) ->
      console.log 'start', timerKey
      console.time timerKey
      fibAsync2(seqNum)
        .then (res) -> next null, res
        .catch (e) -> next e
    .catch (err) ->
      console.timeEnd timerKey
      cb err
    .done (res) ->
      console.timeEnd timerKey
      loglet.log res
      cb null
    
cpsTco = (cb) ->
  timerKey = 'async.fib3.tco'
  console.time timerKey
  asyncFib3.tco seqNum, (err, res) ->
    console.timeEnd timerKey
    if err 
      cb err
    else
      loglet.log res
      cb null

# we want these to fit the pattern of async - I think it's pretty close so far...
class TailCall
  @make: (func, args, cb) ->
    new TailCall func, args, cb
  constructor: (@tail, @args, @cb) ->
    #console.log 'TailCall.ctor', @
  run: () ->
    return @tail @args..., @cb

bluebird = require 'bluebird'



Function::tail = () ->
  func = @
  args = Array::slice.call arguments
  lastArg = args[args.length - 1]
  islastArgFunc = typeof(lastArg) == 'function' or lastArg instanceof Function
  cb = 
    if islastArgFunc
      lastArg
    else
      () ->
  if func.__vmlet?.async
    if islastArgFunc
      args.pop()
    p = new bluebird (resolve, reject) ->
      #loglet.log 'async.tail', func, args
      func args..., (err, res) ->
        if err 
          reject(err)
        else
          resolve(res)
    p.next = cb 
    return p
  else
    return {tail: func, args: args, cb: cb}

isTail = (tail) ->
  #tail instanceof TailCall
  tail.tail and tail.cb

runTail = (tail) ->
  #tail.run()
  return tail.tail tail.args..., tail.cb

# somehow this gets called again...
_tco = (func, args, cb) ->
  args.push cb 
  tail = {tail: func, args: args, cb: cb}
  while cb != tail.tail
    res = tail.tail.apply tail.tail, tail.args
    #loglet.log '_tco', func, args, cb, res
    if res instanceof bluebird
      return _tcoAsync res, cb
    else if res?.tail and res?.cb
      tail = res
    else
      return cb errorlet.create {error: 'invalid_function_return', value: res}
  return tail.tail.apply tail.tail, tail.args

asyncCallCount = 0

_tcoAsync = (promise, cb) ->
  next = promise.next
  asyncCallCount++
  promise.then (res) ->
    #loglet.log '_tcoAsync.then', res, cb
    _tco next , [ null , res ] , cb
  .catch (e) ->
    _tco next , [ e , null ] , cb

Function::tco = (args..., cb) ->
  _tco @, args, cb

asyncFib3 = (n, cb) ->
  if n <= 0
    return cb.tail null, 0
  else if n <= 2
    return cb.tail null, 1
  else 
    return asyncFib3.tail n - 1, (err, n_1) ->
      #loglet.log '__n-1', n_1
      if err 
        return cb.tail err
      return asyncFib3.tail n - 2, (err, n_2) ->
        #loglet.log '__n-2', n_2
        if err 
          return cb.tail err
        else
          return cb.tail null, n_1 + n_2

fs = require 'fs'

fs.readFile.__vmlet = {async: true}

asyncRead = (n, cb) ->
  asyncFib3.tail n, (err, res) ->
    if err 
      cb.tail err
    else
      fs.readFile.tail 'package.json', 'utf8', (err, data) ->
        if err 
          cb.tail err
        else
          cb.tail null, data

class Result
  constructor: (@__vmlet_result) ->

# this is now possible to create a function that's CPS'd to get the result back.
# this of course is going to be "slow"
class RT
  constructor: () ->
  bind: (obj, func) ->
    (args...) ->
      obj[func] args...
  tail: (func, args...) ->
    if func instanceof bluebird
      return func
    #loglet.log 'RT.__tail', func, args
    lastArg = args[args.length - 1]
    isLastArgFunc = typeof(lastArg) == 'function' or lastArg instanceof Function
    cb = if isLastArgFunc then lastArg else () ->
    if func.__vmlet?.async
      if isLastArgFunc
        args.pop()
      p = new bluebird (ok, fail) ->
        func args..., (err, res) ->
          if err 
            fail err
          else
            ok res 
      p.next = cb
      p
    else
      return {tail: func, args: args, cb: cb}
  result: (v) ->
    {__vmlet_result: v}
    #new Result v
  isResult: (v) ->
    #v instanceof Result
    v?.__vmlet_result
  unbind: (v) ->
    if @isResult(v)
      v.__vmlet_result
    else
      v
  tco: (func, args..., cb) ->
    @_tco func, args, cb
  while: (cond, ifTrue, ifFalse) ->
    self = @
    return self.tail cond, (err, res) ->
      if err
        return self.tail ifFalse, err
      else if not res 
        return self.tail isFalse, null, cb
      else 
        return self.while cond, ifTrue, ifFalse, cb
  _tco: (func, args, cb) ->
    args.push cb 
    tail = {tail: func, args: args, cb: cb}
    while cb != tail.tail
      #loglet.log 'RT._tco', tail
      res = tail.tail tail.args...
      if res instanceof bluebird
        return @_tcoAsync res, cb
      else if res?.tail and res?.cb
        tail = res 
      else if @isResult(res)
        return cb null, @unbind res
      else
        return cb errorlet.create {error: 'invalid_tco_function_return', value: res}
    return tail.tail tail.args...
  _tcoAsync: (promise, cb) ->
    self = @
    promise.then (res) ->
      self._tco promise.next, [ null , res ], cb
    .catch (err) ->
      self._tco promise.next, [ err , null ], cb

rt = new RT()

asyncFib4 = (n, cb) ->
  if n <= 0
    return rt.tail cb, null, 0
  else if n <= 2
    return rt.tail cb, null, 1
  else 
    return rt.tail asyncFib4, n - 1, (err, n_1) ->
      if err 
        return rt.tail cb, err
      else
        return rt.tail asyncFib4, n - 2, (err, n_2) ->
          if err 
            return rt.tail cb, err
          else
            return rt.tail cb, null, n_1 + n_2 

sleep = (ms, cb) ->
  p = new bluebird (ok, fail) ->
    setTimeout (() -> ok undefined), ms
  p.next = cb
  p

sleep.__vmlet = {async: true}

# we still ought to generate sync functions if possible...
# that way we can know for sure how to write them out...

# these functions by themselves do not need to be written as CPS...
asyncRead2 = (n, filePath, cb) ->
  try 
    # in order to do this... we should have the following determined
    # 1 - we already know the function ahead of the time (i.e. not a REF object)
    # 2 - we can know for sure that the function is sync (rather than async) - we should still default to sync, I guess.
    
    res = fib n
    return rt.tail fs.readFile, filePath, 'utf8', (err, data) ->
      if err
        return rt.tail cb, err
      else
        try 
          res2 = fib n 
          return rt.tail cb, null, res + res2
        catch e 
          return rt.tail cb, e
  catch e 
    return rt.tail cb, e

syncFibTail = (n) ->
  helper = (n, acc, next) ->
    if n <= 0
      return rt.result acc
    else 
      return rt.tail helper, n - 1, next, acc + next
  return rt.tail helper, n, 0, 1

# how to ensure the context is done correctly?
syncFibNonTail = (n) ->
  if n <= 0
    return rt.result 0
  else if n <= 2
    return rt.result 1
  else 
    return rt.result rt.unbind(syncFibNonTail(n - 1)) + rt.unbind(syncFibNonTail(n - 2))

syncFibNonTail1 = (n) ->
  helper = (n) ->
    if n <= 0
      0
    else if n <= 2
      1
    else
      helper(n - 1) + helper(n - 2)
  return rt.result helper(n)

runMe = () ->
    #.then (next) ->
    #  vmInternal next
  funclet
    .start (next) ->
      baseline next
    .then (next) ->
      timerKey = 'sync.fib.tail'
      console.time timerKey
      rt.tco syncFibTail, seqNum, (err, res) ->
        console.timeEnd timerKey
        if err
          next err
        else
          loglet.log res
          next null
    .then (next) ->
      timerKey = 'sync.fib.nontail'
      console.time timerKey
      rt.tco syncFibNonTail, seqNum, (err, res) ->
        console.timeEnd timerKey
        if err
          next err
        else
          loglet.log res
          next null
    .then (next) ->
      timerKey = 'async.fib4.runtime.tco'
      console.time timerKey
      rt.tco asyncFib4, seqNum, (err, res) ->
        console.timeEnd timerKey
        if err
          next err
        else
          loglet.log 'async.fib4', res
          next null
      ###
      .then (next) ->
        cpsTco next
      .then (next) ->
        promiseBased 'bluebird', next
      .then (next) ->
        promiseBased 'lie', next
      .then (next) ->
        vmScript next
      #.then (next) ->
      #  asyncRead.tco 5, (err, data) ->
      #    if err 
      #      next err
      #    else 
      #      loglet.log 'read-data', data
      #      next null
      .then (next) ->
        timerKey = 'async.read2.runtime.tco'
        console.time timerKey
        rt.tco asyncRead2, seqNum, 'package.json', (err, data) ->
          console.timeEnd timerKey
          if err
            next err
          else
            loglet.log 'read-data'
            loglet.log data
            next null
      .then (next) ->
      console.log 'sleep...'
      rt.tco sleep, 1000, (err) ->
        if err
          next err
        else
          loglet.log 'sleep for', 1000, 'milliseonds'
          next null
      ###
    .catch (e) ->
      loglet.croak e
    .done () ->
      loglet.log 'done.'

runMe()



