loglet = require 'loglet'
errorlet = require 'errorlet'
## maybe we don't deal with defaults just yet...
## let's figure out what we can do

## what would it look like? 
# ( abc def )
# ( < abc type > < def type > )
# ( < abc type default > < abc type default > )
# ( abc : type = default ; ) # these have to do with parsing rules.
# begin name param
# begin name type param
# begin name type 

class Parameter
  constructor: (@name, @type = null, @default = null) ->
  isRequired: () -> 
    not @default
  equals: (p) ->
    if not p instanceof Parameter
      return false
    if not @type == p.type # type ought to be the class definition, which should be **
      return false
    if @isRequired() != p.isRequired()
      return false
    if @default 
      @default.equals(p.default)
    else
      true
  isa: (v) ->
    if @type == null
      true
    else # TODO implement type isa logic here.
      true
  inspect: () ->
    @toString()
  toString: () ->
    "<#{@name} #{@type} #{@default}>"

# begin begin name param begin name param begin name param begin name param paramList
class ParameterList 
  @make: (params = []) ->
    new @ params
  @makeParam: (args...) ->
    new Parameter args...
  constructor: (@params = []) ->
  add: (param) ->
    @params.push param
  equals: (list) ->
    if not list instanceof ParameterList
      return false
    if @params.length != list.params.length
      return false
    for i in [0...@params.length]
      p1 = @params[i]
      p2 = list.params[i]
      if not p1.equals(p2)
        return false
    true
  requiredCount: () ->
    count = 0
    for param in @params
      if param.isRequired()
        count += 1
    count
  ###
  normalize optional arguments. this allows for optional arguments to exist in the middle of a list.
  a , b = null , c
  [ 1 , 2 ] => {a: 1 , b: null, c: 2}
  ####
  _normalize: (args, update) ->
    requiredCount = @requiredCount()
    if args.length < requiredCount
      throw errorlet.create {error: 'insufficient_required_arguments', arguments: args, required: requiredCount}
    optionalCount = args.length - requiredCount
    # optional count gives us an understanding of how many arguments we can use for optional purposes... they might 
    # come before or after all the required counts fulfilled... 
    optionalUsed = 0
    j = 0
    for i in [0...@params.length]
      param = @params[i]
      #loglet.log 'ParameterList.normalize', args[j], param, optionalUsed, optionalCount
      if param.isRequired()
        update param, args[j]
        j++
      else if optionalUsed < optionalCount # we should only consume when we are within our limits
        update param, args[j]
        optionalUsed++
        j++
      else # we must skip
        update param, null
  normalize: (args = []) ->
    #loglet.log 'ParameterList.normalize', args, @
    result = {}
    update = (param, val) ->
      result[param.name] = val
    @_normalize args, update
    result
  normalizeArray: (args = []) ->
    result = []
    update = (param, val) ->
      result.push val
    @_normalize args, update
    result
  inspect: () ->
    @toString()
  toString: () ->
    '(' + (p.toString() for p in @params).join(', ') + ')'

module.exports = ParameterList

