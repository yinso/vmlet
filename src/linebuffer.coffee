loglet = require 'loglet'
errorlet = require 'errorlet'

class Line
  @oneTab: '  '
  constructor: (@level = 0, line = null) ->
    @buffer = []
    if typeof(line) == 'string'
      @buffer.push line
  push: (text) ->
    @buffer.push text
  indent: () ->
    @level++
  outdent: () ->
    @level--
  tab: () ->
    (@constructor.tab for i in [0...@level]).join('')
  toString: () ->
    @tab() + @buffer.join('')
  inspect: () ->
    @toString()

class LineBuffer
  @Line: Line
  constructor: (@level = 0) ->
    @lines = []
    @current = null
  write: (str) ->
    lines = str.split /(\r\n|\r|\n)/
    for line in lines
      @append line
    #loglet.log 'LineBuffer.write', str, @lines
    @
  writeLine: (str) ->
    @write str
    @newline()
  append: (line) ->
    newLine = new Line(@level, line)
    @lines.push newLine
    @current = newLine
    @
  push: (text) ->
    if not @current
      @newline()
    @current.push text
    @
  newline: (text = '') ->
    @append text
    @
  indent: () ->
    @current.indent()
    @
  outdent: () ->
    @current.outdent()
    @
  toString: () ->
    buffer = []
    for line in @lines
      buffer.push line.toString()
    buffer.join '\n'
  inspect: () ->
    @toString()

module.exports = LineBuffer
