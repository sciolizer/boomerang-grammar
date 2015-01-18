require! assert
boomerang = require \../index

o = (left, right) ->
  boomerang.any [left, right]

describe 'parse words and arrays' -> ``it``
  .. "should parse 'the' as the identity function" ->
    iterator = boomerang.parse \the <[the]>
    item = iterator.next()
    assert.equal false, item.done
    assert.deepEqual [], item.value.strings
    assert.deepEqual [3, 7], item.value.stack-modifier([3, 7])
    item := iterator.next()
    assert.equal true, item.done
  .. "should parse 'the quick' as the identity function" ->
    iterator = boomerang.parse <[the quick]> <[the quick]>
    item = iterator.next()
    assert.equal false, item.done
    assert.deepEqual [], item.value.strings
    assert.deepEqual [3, 7], item.value.stack-modifier([3, 7])
    item := iterator.next()
    assert.equal true, item.done
  .. "should parse 'ye' as an error" ->
    iterator = boomerang.parse \the <[ye]>
    item = iterator.next()
    assert.equal false, item.done
    assert.equal \the, item.value.expected
    item := iterator.next()
    assert.equal true, item.done
  .. "should parse 'the slow' as an error" ->
    iterator = boomerang.parse <[the quick]> <[the slow]>
    item = iterator.next()
    assert.equal false, item.done
    assert.equal \quick, item.value.expected
    item := iterator.next()
    assert.equal true, item.done

describe \print -> ``it``
  .. 'should print string as self' ->
    iterator = boomerang.print \the, []
    item = iterator.next()
    assert.equal false, item.done
    assert.deepEqual <[the]>, item.value.strings
    assert.deepEqual [], item.value.stack
    item := iterator.next()
    assert.equal true, item.done
  .. 'should dump constant strings out as self' ->
    iterator = boomerang.print <[the quick brown]>, []
    item = iterator.next()
    assert.equal false, item.done
    assert.deepEqual <[the quick brown]>, item.value.strings
    assert.deepEqual [], item.value.stack
    item := iterator.next()
    assert.equal true, item.done

describe 'parse functions' -> ``it``
  .. 'should invoke custom parse function' ->
    custom-parser =
      parse: (strings) ->*
        yield do
          strings: strings
          stackModifier: (stack) -> [3] ++ stack
    iterator = boomerang.parse custom-parser, <[the quick]>
    item = iterator.next()
    assert.equal false, item.done
    assert.deepEqual <[the quick]>, item.value.strings
    assert.deepEqual [3,4], item.value.stack-modifier([4])
    item := iterator.next()
    assert.equal true, item.done

describe 'pure' -> ``it``
  .. 'should consume the right number of stack entries' ->
    reducer = (a, b, c) -> a + b + c
    parser = boomerang.pure reducer
    iterator = parser.parse <[the quick]>
    item = iterator.next()
    assert.equal false, item.done
    assert.deepEqual <[the quick]>, item.value.strings
    assert.deepEqual [6, 4, 5], item.value.stack-modifier([1, 2, 3, 4, 5])
    item = iterator.next()
    assert.equal true, item.done
  .. 'should always return at least one value' ->
    reducer = (a, b, c) -> a + b + c
    parser = boomerang.pure reducer
    iterator = parser.parse <[the quick]>
    item = iterator.next()
    assert.equal false, item.done
    assert.deepEqual <[the quick]>, item.value.strings
    assert.deepEqual [6], item.value.stack-modifier([1, 2, 3])
    item = iterator.next()
    assert.equal true, item.done
  .. 'should throw error on stack depletion' ->
    reducer = (a, b, c) -> a + b + c
    parser = boomerang.pure reducer
    iterator = parser.parse <[the quick]>
    item = iterator.next()
    assert.equal false, item.done
    assert.deepEqual <[the quick]>, item.value.strings
    try
      item.value.stack-modifier [1,2]
      assert.fail 'stack-modifier did not throw exception'
    catch {message}
      assert.equal 'grammar bug: stack depleted', message
    assert.deepEqual [6], item.value.stack-modifier([1, 2, 3])
    item := iterator.next()
    assert.equal true, item.done

describe 'choice' -> ``it``
  .. 'should parse choices' ->
    parser = 'here' `o` 'there'
    iterator = parser.parse <[here boy]>
    item = iterator.next()
    assert.equal false, item.done
    assert.deepEqual [\boy], item.value.strings
    assert.deepEqual [3,4], item.value.stack-modifier([3,4])
    item := iterator.next()
    assert.equal false, item.done
    assert.deepEqual <[here boy]>, item.value.strings
    assert.equal true, item.value.error
    assert.equal \there, item.value.expected
    item := iterator.next()
    assert.equal true, item.done
  .. 'constant after choice' ->
    parser = ['a' `o` 'the', 'quick']
    iterator = boomerang.parse parser, <[the quick]>
    item = iterator.next()
    assert.equal false, item.done
    assert.deepEqual <[the quick]>, item.value.strings
    assert.equal true, item.value.error
    assert.equal \a, item.value.expected
    item := iterator.next()
    assert.equal false, item.done
    assert.deepEqual [], item.value.strings
    assert.deepEqual [3,4], item.value.stack-modifier([3,4])
    item := iterator.next()
    assert.equal true, item.done
  .. 'constant before choice' ->
    parser = ['the', 'quick' `o` 'slow']
    iterator = boomerang.parse parser, <[the slow]>
    item = iterator.next()
    assert.equal false, item.done
    assert.deepEqual <[slow]>, item.value.strings
    assert.equal true, item.value.error
    assert.equal \quick, item.value.expected
    item := iterator.next()
    assert.equal false, item.done
    assert.deepEqual [], item.value.strings
    assert.deepEqual [3,4], item.value.stack-modifier([3,4])
    item := iterator.next()
    assert.equal true, item.done
  .. 'chained choices' ->
    parser = ['a' `o` 'the', 'quick' `o` 'slow']
    iterator = boomerang.parse parser, <[the slow]>
    item = iterator.next()
    assert.equal false, item.done
    assert.deepEqual <[the slow]>, item.value.strings
    assert.equal true, item.value.error
    assert.equal \a, item.value.expected
    item := iterator.next()
    assert.equal false, item.done
    assert.deepEqual <[slow]>, item.value.strings
    assert.equal true, item.value.error
    assert.equal \quick, item.value.expected
    item := iterator.next()
    assert.equal false, item.done
    assert.deepEqual [], item.value.strings
    assert.deepEqual [3,4], item.value.stack-modifier([3,4])
    item := iterator.next()
    assert.equal true, item.done

describe 'mini-parse' -> ``it``
  .. 'should push a number' ->
    mini-parser = (i) ->
      parsed = parseInt i
      if isNaN parsed then void else parsed
    parser = boomerang.mini-parse mini-parser, "<number>"
    iterator = parser.parse <[3 chimpanzees]>
    item = iterator.next()
    assert.equal false, item.done
    assert.deepEqual <[chimpanzees]>, item.value.strings
    assert.deepEqual [3, 4], item.value.stack-modifier(4)
    item := iterator.next()
    assert.equal true, item.done
  .. 'should fail on an empty string' ->
    mini-parser = (i) ->
      parsed = parseInt i
      if isNaN parsed then void else parsed
    parser = boomerang.mini-parse mini-parser, "<number>"
    iterator = parser.parse []
    item = iterator.next()
    assert.equal false, item.done
    assert.deepEqual [], item.value.strings
    assert.equal true, item.value.error
    assert.equal "<number>", item.value.expected
    item := iterator.next()
    assert.equal true, item.done
  .. 'should fail on mini-parse failure' ->
    mini-parser = (i) ->
      parsed = parseInt i
      if isNaN parsed then void else parsed
    parser = boomerang.mini-parse mini-parser, "<number>"
    iterator = parser.parse <[hockey puck]>
    item = iterator.next()
    assert.equal false, item.done
    assert.deepEqual <[hockey puck]>, item.value.strings
    assert.equal true, item.value.error
    assert.equal "<number>", item.value.expected
    item := iterator.next()
    assert.equal true, item.done

describe 'nop' -> ``it``
  .. 'should leave things as they are' ->
    iterator = boomerang.nop.parse <[no touchy]>
    item = iterator.next()
    assert.equal false, item.done
    assert.deepEqual <[no touchy]>, item.value.strings
    assert.deepEqual [3,4], item.value.stack-modifier([3,4])
    item := iterator.next()
    assert.equal true, item.done

describe 'print function' -> ``it``
  b =
    print: (stack) ->*
      if stack.length > 0 && stack[0] == 7
        yield do
          strings: <[cool yo]>
          stack: stack.slice(1)
  .. 'should call my print function' ->
    iterator = boomerang.print b, [7]
    item = iterator.next()
    assert.equal item.done, false
    assert.deepEqual item.value.strings, <[cool yo]>
    assert.deepEqual item.value.stack, []
    item := iterator.next()
    assert.equal item.done, true
  .. 'should give nothing if wrong stack' ->
    iterator = boomerang.print b, [6]
    item = iterator.next()
    assert.equal true, item.done

describe 'pure print' -> ``it``
  reducer = (left, right) -> { left, right }
  expander = (item) -> if item && item.left && item.right then [item.left, item.right] else void
  b = boomerang.pure reducer, expander
  .. 'pop stack on match' ->
    iterator = boomerang.print b, [{ left: 3, right: 4 }]
    item = iterator.next()
    assert.equal item.done, false
    assert.deepEqual item.value.strings, []
    assert.deepEqual item.value.stack, [3, 4]
    item := iterator.next()
    assert.equal item.done, true
  .. 'fail on empty stack' ->
    iterator = boomerang.print b, []
    item = iterator.next()
    assert.equal item.done, true
  .. 'fail on stack with wrong item' ->
    iterator = boomerang.print b, [{ hello: \sugar }]
    item = iterator.next()
    assert.equal item.done, true
  .. 'print multiple options' ->
    iterator = boomerang.print([\fancy, b] `o` \bland, [{ left: 3, right: 4 }])
    item = iterator.next()
    assert.equal item.done, false
    assert.deepEqual item.value.strings, <[fancy]>
    assert.deepEqual item.value.stack, [3, 4]
    item := iterator.next()
    assert.equal item.done, false
    assert.deepEqual item.value.strings, <[bland]>
    assert.deepEqual item.value.stack, [{ left: 3, right: 4}]
    item := iterator.next()
    assert.equal item.done, true
  .. 'print only the possible option' ->
    iterator = boomerang.print([\fancy, b] `o` \bland, [])
    item = iterator.next()
    assert.equal item.done, false
    assert.deepEqual item.value.strings, <[bland]>
    assert.deepEqual item.value.stack, []
    item := iterator.next()
    assert.equal item.done, true

describe 'print choice' -> ``it``
  .. 'print both options' ->
    iterator = boomerang.print(\a `o` \the, [])
    item = iterator.next()
    assert.equal item.done, false
    assert.deepEqual item.value.strings, <[a]>
    assert.deepEqual item.value.stack, []
    item := iterator.next()
    assert.equal item.done, false
    assert.deepEqual item.value.strings, <[the]>
    assert.deepEqual item.value.stack, []
    item := iterator.next()
    assert.equal item.done, true

describe 'more pure' -> ``it``
  color-boomerang = boomerang.pure(-> { red: {} }, (color) -> if color && color.red then [] else void)
  .. 'no-arg pure' ->
    iterator = boomerang.parse color-boomerang, <[roy gee]>
    pt = new Parse-tester iterator
    pt.success [3, 4], [{red:{}}, 3, 4], <[roy gee]>
    pt.done
  .. 'two pures back to back' ->
    property-boomerang = boomerang.pure((color) -> { isColor: { color } }, (property) -> if property && property.isColor then [property.isColor.color] else void)
    iterator = boomerang.parse [property-boomerang, color-boomerang, \red], <[red]>
    pt = new Parse-tester iterator
    pt.success [], [ { isColor: { color: { red: {} } } } ], []
    pt.done

describe \any -> ``it``
  .. 'should do the thing on a singleton list' ->
    iterator = boomerang.parse(boomerang.any([\red]), <[red medallion]>)
    pt = new Parse-tester iterator
    pt.success [], [], <[medallion]>
    pt.done
  .. 'should attempt the first option' ->
    iterator = boomerang.parse(boomerang.any(<[red black]>), <[red medallion]>)
    pt = new Parse-tester iterator
    pt.success [], [], <[medallion]>
    pt.error-expect \black, <[red medallion]>
    pt.done
  .. 'should attempt the second option' ->
    iterator = boomerang.parse(boomerang.any(<[red black]>), <[black medallion]>)
    pt = new Parse-tester iterator
    pt.error-expect \red, <[black medallion]>
    pt.success [], [], <[medallion]>
    pt.done
  .. 'should not consume when none of them work' ->
    iterator = boomerang.parse(boomerang.any(<[red black]>), <[purple medallion]>)
    pt = new Parse-tester iterator
    pt.error-expect \red, <[purple medallion]>
    pt.error-expect \black, <[purple medallion]>
    pt.done

class Parse-tester
  (@iterator) ->
  error-expect: (expected, strings) ->
    item = @iterator.next()
    assert.equal false, item.done
    assert.equal true, item.value.error
    if expected != void
      assert.equal expected, item.value.expected
    if strings != void
      assert.deepEqual strings, item.value.strings
  success: (stack-input, stack-output, strings) ->
    item = @iterator.next()
    assert.equal false, item.done
    if item.value.error
      assert.fail "error, unexpected: " + item.value.expected, "successful parse", "expected successful parse, actual error expecting: " + item.value.expected, "next"
    if void != strings
      assert.deepEqual strings, item.value.strings
    if void != stack-input
      new-stack = item.value.stack-modifier(stack-input)
      assert.deepEqual stack-output, new-stack
  done: ->
    item = @iterator.next()
    assert.equal true, item.done
