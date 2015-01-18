{
  map
} = require \prelude-ls

any = (choices) ->
  parse: (strings) ->*
    for choice in choices
      yield from parse(choice, strings)
  debug: ->
    "any(" + join(",", map(debug, choices)) + ")"
  print: (stack) ->*
    for choice in choices
      yield from print(choice, stack)

either = (left, right) ->
  any [left, right]

optional = (parser) -> nop `either` parser

nop =
  parse: (strings) ->*
    yield do
      strings: strings
      stackModifier: (stack) -> stack
  debug: ->
    "nop"
  print: (stack) ->*
    yield do
      strings: []
      stack: stack

# Input:
#   parser: a boomerang
#   strings: input remaining to be parsed
# Output: generator of
#   strings: input remaining to be parsed
#   stackModifier: parsed value :: [] -> []. Stack may grow, shrink, or stay the same.
#   error: true or undefined. stackModifier is undefined when true
#   expected: in an error, the string that was expected to be next
parse = (parser, strings) ->*
  switch parser.constructor
  case String
    if strings.length > 0 && strings[0] == parser
      yield do
        strings: strings.slice(1)
        stackModifier: (result) -> result
    else
      yield do
        strings: strings
        expected: parser
        error: true
  case Array
    yield from parse-array(parser, strings)
  case Object
    yield from parser.parse(strings)
  default ...

print = (parser, stack) ->*
  switch parser.constructor
  case String
    yield do
      strings: [parser]
      stack: stack
  case Array
    yield from print-array parser, stack
  case Object
    yield from parser.print stack
  default ...

debug = (parser) ->
  if void == parser
    return "void"
  switch parser.constructor
  case String
    parser
  case Array
    map debug, parser
  case Object
    parser.debug()
  default
    "unknown"

# Input:
#   array: an array of boomerangs
#   strings: input remaining to be parsed.
# Output: same as for parse
parse-array = (array, strings) ->*
  if array.length == 0
    yield do
      strings: strings
      stackModifier: (result) -> result
  else
    head-iterator = parse(array[0], strings)
    head-item = head-iterator.next()
    while not head-item.done
      if head-item.value.error
        yield head-item.value
      else
        tail-iterator = parse-array(array.slice(1), head-item.value.strings)
        tail-item = tail-iterator.next()
        while not tail-item.done
          if tail-item.value.error
            yield tail-item.value
          else
            yield do
              strings: tail-item.value.strings
              stackModifier: head-item.value.stack-modifier << tail-item.value.stack-modifier
          tail-item := tail-iterator.next()
      head-item := head-iterator.next()

print-array = (array, stack) ->*
  if array.length == 0
    yield do
      strings: []
      stack: stack
  else
    head-iterator = print array[0], stack
    head-item = head-iterator.next()
    while not head-item.done
      tail-iterator = print-array array.slice(1), head-item.value.stack
      tail-item = tail-iterator.next()
      while not tail-item.done
        yield do
          strings: head-item.value.strings ++ tail-item.value.strings
          stack: tail-item.value.stack
        tail-item := tail-iterator.next()
      head-item := head-iterator.next()

# Input:
#   reducer: any function with a fixed number of arguments
#   expander: function of one argument that returns a list of stack items, or returns void.
#     Generaly the size of the list will match the number of arguments on reducer
# Output:
#   a boomerang which consumes no input and applies the function to the current stack
pure = (reducer, expander) ->
  parse: (strings) ->*
    yield do
      strings: strings
      stackModifier: (stack) ->
        if stack.length < reducer.length
          throw Error 'grammar bug: stack depleted'
        args = stack.slice 0, reducer.length
        [reducer.apply @, args] ++ stack.slice reducer.length
  debug: ->
    "pure"
  print: (stack) ->*
    if stack.length > 0
      prefix = expander(stack[0])
      if prefix != void
        yield do
          strings: []
          stack: prefix ++ stack.slice(1)

# Input:
#   mini-parser: a function which takes a string and returns a value.
#     Returning undefined indicates the parse failed.
#   expected: the string to display to the user on parse failure, e.g. "<number>"
mini-parse = (mini-parser, expected, to-string) ->
  parse: (strings) ->*
    if strings.length > 0
      val = mini-parser strings[0]
      if val == void
        yield do
          strings: strings
          error: true
          expected: expected
      else
        yield do
          strings: strings.slice 1
          stackModifier: (stack) -> [val] ++ stack
    else
      yield do
        strings: strings
        error: true
        expected: expected
  debug: ->
    "mini-parse(" + expected + ")"
  print: (stack) ->*
    yield do
      strings: if to-string == void then "" + stack[0] else to-string(stack[0])
      stack: stack.slice(1)

recursive = (boomerang-supplier) ->
  parse: (strings) ->*
    yield from parse(boomerang-supplier(), strings)
  debug: ->
    "recursive"
  print: (stack) ->*
    yield from print(boomerang-supplier(), stack)

module.exports =
  any: any
  either: either
  debug: debug
  miniParse: mini-parse
  nop: nop
  optional: optional
  parse: parse
  print: print
  pure: pure
  recursive: recursive
