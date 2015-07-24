util = require './util'
_level = 0

indent = (count) ->
  ('  ' for i in [0..._level]).join('') + (' ' for i in [0...count]).join('')

tab = (name, show = true) -> 
  after = 
    if show
      "--> #{name}"
    else
      (' ' for i in [0...7]).join('')
  ('  ' for i in [0..._level]).join('') + after

untab = (name, show = true) ->
  after = 
    if show
      "<-- #{name}"
    else
      (' ' for i in [0...7]).join('')
  ('  ' for i in [0..._level]).join('') + after

_traced = []

isTracedHead = (proc) ->
  for [ orig , traced ], i in _traced 
    if orig == proc 
      return i
  -1

isTracedTail = (proc) -> 
  for [ orig , traced ], i in _traced 
    if traced == proc
      return true
  -1

_temp = 0

tempName = () -> 
  "__$#{_temp++}"

objToStr = (arg) ->
  if arg == null 
    return [ indent(2) + 'null' ]
  if arg == undefined 
    return [ indent(2) + 'undefined' ]
  for str, i in util.prettify(arg).split '\n'
    if i == 0 
      indent(2) + str
    else
      indent(4) + str

printObj = (arg) ->
  strs = objToStr arg 
  for str in strs 
    console.log str

_trace = (name, args) -> 
  console.log tab(name)  
  for arg in args 
    printObj arg

_untrace = (name, arg) ->
  console.log untab(name)
  printObj arg

trace = (name, proc) -> 
  if arguments.length == 1 
    proc = name 
    name = 
      if proc.name?.length > 0 
        proc.name 
      else 
        tempName()
  res = isTracedHead proc
  if res > -1 
    return _traced[res][1]
  traced = (args...) ->
    _trace name, args
    _level++
    try 
      res = proc.apply @, args
    finally 
      _level--
    _untrace name, res
    res
  _traced.push [ proc , traced ]
  traced 

untrace = (traced) ->
  res = isTracedTail traced 
  if res > -1 # exists
    orig = _traced[res][0]
    _traced.splice i, 1
    return orig
  else
    traced 

log = (args...) ->
  for arg in args
    printObj arg

module.exports = 
  trace: trace
  untrace: untrace
  log: log
