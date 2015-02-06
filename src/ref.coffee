class Ref
  constructor: (name) ->
    @name = 
      if typeof(name) == 'string'
        name
      else if name.hasOwnProperty('symbol')
        name.symbol
      else
        throw {error: 'invalid_ref', name: name}

module.exports = Ref
