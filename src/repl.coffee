readline = require 'readline'
{EventEmitter} = require 'events'
fs = require 'fs'

extend = (objects...) ->
  result = {}
  for obj in objects 
    for key, val of obj 
      if obj.hasOwnProperty(key)
        result[key] = val
  result

filter = (ary, pred) ->
  result = []
  for item in ary 
    if pred item 
      result.push item 
  result

class Repl extends EventEmitter
  @start: (options = {}) ->
    defaultOptions = 
      input: process.stdin
      output: process.stdout
      error: process.stderr
      prompt: '$>'
      onEval: (repl, cmd, cb) ->
        if cmd == 'undefined'
          cb null, undefined
        else if cmd == 'error'
          cb new Error("this_is_an_error_object")
        else
          cb null, cmd
      historyFile: '.history.log'
      historySize: 30
      onError: (repl, err) ->
        repl.errorWriteLine '<ERROR>'
        repl.errorWriteLine "#{err}"
        if err.fileName
          repl.errorWriteLine "-- on #{err.fileName}, #{err.lineNumber}"
        repl.errorWriteLine err.stack
      onResult: (repl, res) ->
        repl.writeLine "#{res}"
      onParse: (repl, text) ->
        {state: 'ok', parsed: text}
      onTabCompletion: (repl, text) ->
        [["#{text}_tabbed"],text] 
    new Repl extend {}, defaultOptions, options
  loadHistory: () ->
    historySize = @options.historySize or 30
    repl = @
    @readline._addHistory = () -> # overwrite the native _addHistory function provided by node
      #if repl.commands.hasOwnProperty(@line)
      #  return ''
      if @line.length == 0
        return ''
      if @history.length == 0 or @history[0] != @line
        @history.unshift @line
        if @history.length > historySize
          @history.pop()
      @historyIndex = -1
      return @history[0]
    try
      @readline.history = fs.readFileSync(@options.historyFile, 'utf8').split('\n').reverse()
      @readline.historyIndex = -1
    catch e
      []
  saveHistory: () ->
    history = filter @readline.history.reverse(), (line) =>
      not @commands.hasOwnProperty(line)
    fs.writeFileSync @options.historyFile, history.join('\n'), 'utf8'
  constructor: (@options) ->
    @readline = readline.createInterface
      input: @options.input
      output: @options.output
      completer: @onTabCompletion # this is optional... 
      terminal: true
    @commands = []
    @continuingPrompt = (' ' for i in [0...@options.prompt.length]).join('')
    @readline.on 'close', @onExit
    @readline.on 'SIGINT', @onInterrupt
    @readline.on 'SIGCONT', @displayPrompt
    @readline.on 'line', @onLine
    @loadHistory()
    @commands['.history'] =
      help: 'Show the history'
      action: (repl) =>
        out = (h for h in @readline.history)
        repl.writeLine out.reverse().join('\n')
    @commands['.quit'] =
      help: 'Quit the program'
      action: (repl) =>
        repl.readline.close()
    @beenInterrupted = false
    @buffer = ''
    @displayPrompt()
  onLine: (cmd) =>
    @beenInterrupted = false
    fullCommand = @buffer + cmd + '\n'
    if @commands.hasOwnProperty(cmd) # this is a command
      @commands[cmd].action @
      @displayPrompt()
    else 
      try
        {state, parsed} = @options.onParse @, fullCommand
        if state == 'ok' # the parse is successful - the parsed has the parsed expression.
          @buffer = ''
          @options.onEval @, fullCommand, parsed, @handleResult
        else if state == 'more' # we expect more line to come through
          @buffer = fullCommand
          @displayPrompt()
        else if state == 'error' # parsed is done but the result is failure.
          @buffer = ''
          @options.onError @, parsed
          @displayPrompt()
        else # unknown parsing state
          throw new Error("unknown_parse_state: #{fullCommand} ==> #{state}, #{parsed}")
      catch e
        @options.onError @, e
        @displayPrompt()
  writeLine: (text) ->
    @readline.output.write "#{text}\n"
  write: (text) ->
    @readline.output.write text
  errorWrite: (text) ->
    @options.error.write "!!! #{text}"
  errorWriteLine: (text) ->
    @options.error.write "!!! #{text}\n"
  handleResult: (err, res) =>
    try
      if err
        @options.onError @, err
      else
        @options.onResult @, res
    catch e
      @errorWriteLine '<REPL_ERROR>'
      @errorWriteLine "#{err}"
    @displayPrompt()
  onInterrupt: () =>
    @readline.clearLine()
    if @beenInterrupted
      @beenInterrupted = false
      @readline.close() # close down the whole thing...
    else
      @beenInterrupted = true
      @readline.output.write '(^C again to quit)\n'
      @displayPrompt()
  displayPrompt: (preserveCursor = true) =>
    prompt =
      if @buffer.length > 0
        @continuingPrompt + ' '
      else
        @options.prompt + ' '
    @readline.setPrompt prompt
    @readline.prompt preserveCursor
  onExit: () =>
    @emit 'exit'
    @saveHistory()
    process.exit()    
  onTabCompletion: (text) =>
    @options.onTabCompletion @, text
    

module.exports = Repl
