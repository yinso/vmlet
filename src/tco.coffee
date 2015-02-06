
class TailCall
  @make: (func, args) ->
    new TailCall func, args
  constructor: (@inner, @args) ->

Function::tail = () ->
  TailCall.make @, arguments

Function::tco = (args..., cb) ->
  tail = TailCall.make @, arguments
  while cb != tail.inner
    tail = tail.inner.apply @, tail.args
  cb.apply @, tail.args

