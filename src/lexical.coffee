# a lexical environment is similar to an environment but it is not really.

class Lexical
  constructor: () ->
    @level = 0
    @map = {} # a map 
  beginScope: () ->
  endScope: () ->

module.exports = Lexical