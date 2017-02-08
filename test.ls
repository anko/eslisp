#!/usr/bin/env lsc
consume-map = require \source-map .SourceMapConsumer .bind!
{ spawn } = require \child_process
{ unique } = require \prelude-ls
require! <[ tape tmp fs uuid rimraf path ]>
concat = require \concat-stream

esl = require \./src/index.ls

test = (name, test-func) ->
  tape name, (t) ->
    test-func.call t  # Make `this` refer to tape's asserts
    t.end!            # Automatically end tests
test-async = (name, test-func) ->
  tape name, (t) ->
    test-func.call t
    # Don't end automatically

test "nothing" ->
  esl ""
    .. `@equals` ""

test "plain comment" ->
  esl "\n; nothing\n"
    ..`@equals` ""

test "first-line shebang" ->
  esl "#!something goes here\n(hello)\n"
    ..`@equals` "hello();"

test "plain numeric literal" ->
  esl "3"
    ..`@equals` "3;"

test "plain negative numeric literal" ->
  esl "-3"
    ..`@equals` "-3;"

test "plain literal with trailing digits" ->
  esl "asd39"
    ..`@equals` "asd39;"

test "plain string literal" ->
  esl '"ok then"'
    ..`@equals` "'ok then';"

test "string literal escaping" ->
  esl '"\\"ok\\" then"'
    ..`@equals` "'\"ok\" then';"

test "string literal newline" ->
  esl '"ok\nthen"'
    ..`@equals` "'ok\\nthen';"

test "string literal newline escape" ->
  esl '"ok\\nthen"'
    ..`@equals` "'ok\\nthen';"

test "n-ary plus" ->
  esl "(+ 3 4 5)"
    ..`@equals` "3 + (4 + 5);"

test "plus nests" ->
  esl "(+ 1 (+ 2 3))"
    ..`@equals` "1 + (2 + 3);"

test "unary plus" ->
  esl "(+ 1)"
    ..`@equals` "+1;"

test "unary minus" ->
  esl "(- 1)"
    ..`@equals` "-1;"

test "n-ary minus" ->
  esl "(- 10 2 1)"
    ..`@equals` "10 - (2 - 1);"

test "n-ary multiplication" ->
  esl "(* 1 2 3)"
    ..`@equals` "1 * (2 * 3);"

test "unary multiplication is invalid" ->
  (-> esl "(* 2)")
    ..`@throws` Error

test "n-ary division" ->
  esl "(/ 1 2 3)"
    ..`@equals` "1 / (2 / 3);"

test "unary division is invalid" ->
  (-> esl "(/ 2)")
    ..`@throws` Error

test "n-ary modulus" ->
  esl "(% 1 2 3)"
    ..`@equals` "1 % (2 % 3);"

test "prefix increment expression" ->
  esl "(_++ x)"
    ..`@equals` "x++;"

test "postfix incremente expression" ->
  esl "(++_ x) (++ x)"
    ..`@equals` "++x;\n++x;"

test "prefix decrement expression" ->
  esl "(--_ x) (-- x)"
    ..`@equals` "--x;\n--x;"

test "postfix decrement expression" ->
  esl "(_-- x)"
    ..`@equals` "x--;"

test "chainable logical expressions" ->
  esl "(&& 1 2 3) (|| 1 2 3)"
    ..`@equals` "1 && (2 && 3);\n1 || (2 || 3);"

test "unary logical not" ->
  esl "(! 1)"
    ..`@equals` "!1;"

test "unary delete" ->
  esl "(delete x)"
    ..`@equals` "delete x;"

test "unary delete" ->
  esl "(typeof x)"
    ..`@equals` "typeof x;"

test "unary void" ->
  esl "(void x)"
    ..`@equals` "void x;"

test "chainable instanceof" -> # yes, making that chain is maybe odd
  esl "(instanceof x y z)"
    ..`@equals` "x instanceof (y instanceof z);"

test "chainable in" ->
  esl "(in x y z)"
    ..`@equals` "x in (y in z);"

test "bitwise &, |, ^ are chainable" ->
  esl "(& 1 2 3) (| 1 2 3) (^ 1 2 3)"
    ..`@equals` "1 & (2 & 3);\n1 | (2 | 3);\n1 ^ (2 ^ 3);"

test "bitwise shifts are chainable" ->
  esl "(<< 1 2 3) (>> 1 2 3) (>>> 1 2 3)"
    ..`@equals` "1 << (2 << 3);\n1 >> (2 >> 3);\n1 >>> (2 >>> 3);"

test "unary bitwise not" ->
  esl "(~ x)"
    ..`@equals` "~x;"

test "equals expression, chainable" ->
  esl "(== x y z)"
    ..`@equals` "x == (y == z);"
test "disequals expression, chainable" ->
  esl "(!= x y z)"
    ..`@equals` "x != (y != z);"
test "strong-equals expression, chainable" ->
  esl "(=== x y z)"
    ..`@equals` "x === (y === z);"
test "strong-disequals expression, chainable" ->
  esl "(!== x y z)"
    ..`@equals` "x !== (y !== z);"

test "comparison expressions, chainable" -> # >, <= and >= are same code path
  esl "(< x y z)"
    ..`@equals` "x < (y < z);"

test "sequence expression (comma-separated expressions)" ->
  esl "(seq x y z)"
    ..`@equals` "x, y, z;"

test "function expression" ->
  esl "(lambda (x) (return (+ x 1)))"
    ..`@equals` "(function (x) {\n    return x + 1;\n});"

test "function expression with name" ->
  esl "(lambda f (x) (return (+ x 1)))"
    ..`@equals` "(function f(x) {\n    return x + 1;\n});"

test "function declaration" ->
  esl "(function f (x) (return (+ x 1)))"
    ..`@equals` "function f(x) {\n    return x + 1;\n}"

test "function declaration without name throws error" ->
  -> esl "(function (x) (return (+ x 1)))"
    ..`@throws` Error

test "function with no arguments" ->
  esl "(lambda () (return 1))"
    ..`@equals` "(function () {\n    return 1;\n});"

test "assignment expressions" ->
  <[ += -= *= /= %=
     &= |= ^= >>= <<= >>>= ]> .for-each ~>
    esl "(#it x 1)"
      ..`@equals` "x #it 1;"

test "variable declaration statement" ->
  esl "(var f)"
    ..`@equals` "var f;"

test "variable declaration and assignment" ->
  esl "(var f (lambda (x) (return (+ x 1))))"
    ..`@equals` "var f = function (x) {\n    return x + 1;\n};"

test "empty statement" ->
  esl "()"
    ..`@equals` "null;"

test "break statement" ->
  esl "(while true (break))"
    ..`@equals` "while (true) {\n    break;\n}"

test "continue statement" ->
  esl "(while true (continue))"
    ..`@equals` "while (true) {\n    continue;\n}"

test "break to label" ->
  esl "(label x (while true (break x)))"
    ..`@equals` "x:\n    while (true) {\n        break x;\n    }"

test "continue to label" ->
  esl "(label x (while true (continue x)))"
    ..`@equals` "x:\n    while (true) {\n        continue x;\n    }"

test "stand-alone label" ->
  esl "(label x)"
    ..`@equals` "x:;"

test "labeled statement" ->
  esl "(label foo (while (-- n)))"
    ..`@equals` "foo:\n    while (--n) {\n    }"

test "labeled expression" ->
  esl "(label label (* x 4))"
    ..`@equals` "label:\n    x * 4;"

test "return statement" ->
  esl "(lambda () (return \"hello there\"))"
    ..`@equals` "(function () {\n    return 'hello there';\n});"

test "member expression" ->
  esl "(. console log)"
    ..`@equals` "console.log;"

test "explicit block statement" ->
  esl "(block a b)"
    ..`@equals` "{\n    a;\n    b;\n}"

test "call expression" ->
  esl "(f)"
    ..`@equals` "f();"

test "member, then call with arguments" ->
  esl '((. console log) "hi")'
    ..`@equals` "console.log('hi');"

test "func with member and call in it" ->
  esl "(lambda (x) ((. console log) x))"
    ..`@equals` "(function (x) {\n    console.log(x);\n});"

test "switch statement" ->
  esl '''
      (switch (y)
              ((== x 5) ((. console log) "hi") (break))
              (default  (yes)))
      '''
    ..`@equals` """
                switch (y()) {
                case x == 5:
                    console.log('hi');
                    break;
                default:
                    yes();
                }
                """

test "if-statement with blocks" ->
  esl '(if (+ 1 0) (block ((. console log) "yes") (x)) (block 0))'
    ..`@equals` """
      if (1 + 0) {
          console.log(\'yes\');
          x();
      } else {
          0;
      }
      """

test "if-statement with expressions" ->
  esl '(if (+ 1 0) (x) 0)'
    ..`@equals` """
      if (1 + 0)
          x();
      else
          0;
      """

test "if-statement without alternate" ->
  esl '(if (+ 1 0) (block ((. console log) "yes") (x)))'
    ..`@equals` """
      if (1 + 0) {
          console.log(\'yes\');
          x();
      }
      """

test "ternary expression" ->
  esl '(?: "something" 0 1)'
    ..`@equals` "'something' ? 0 : 1;"

test "while loop with explicit body" ->
  esl '(while (-- n) (block
                      ((. console log) "ok")
                      ((. console log) "still ok")))'
    ..`@equals` "while (--n) {\n    console.log('ok');\n    console.log('still ok');\n}"

test "while loop with explicit body that contains a block" ->
  esl '(while (-- n) (block
                      (block a)))'
    ..`@equals` "while (--n) {\n    {\n        a;\n    }\n}"

test "while loop with implicit body" ->
  esl '(while (-- n) ((. console log) "ok")
                     ((. console log) "still ok"))'
    ..`@equals` "while (--n) {\n    console.log('ok');\n    console.log('still ok');\n}"

test "do/while loop with implicit body" ->
  esl '(dowhile (-- n) ((. console log) "ok")
                     ((. console log) "still ok"))'
    ..`@equals` "do {\n    console.log('ok');\n    console.log('still ok');\n} while (--n);"

test "do/while loop with explicit body" ->
  esl '(dowhile (-- n) (block
                        ((. console log) "ok")
                        ((. console log) "still ok")))'
    ..`@equals` "do {\n    console.log('ok');\n    console.log('still ok');\n} while (--n);"

test "for loop with implicit body" ->
  esl '(for (var x 1) (< x 10) (++ x) ((. console log) "ok")
                                    ((. console log) "still ok"))'
    ..`@equals` "for (var x = 1; x < 10; ++x) {\n    console.log('ok');\n    console.log('still ok');\n}"

test "for loop with explicit body" ->
  esl '(for (var x 1) (< x 10) (++ x) (block ((. console log) "ok")
                                           ((. console log) "still ok")))'
    ..`@equals` "for (var x = 1; x < 10; ++x) {\n    console.log('ok');\n    console.log('still ok');\n}"

test "for loop with no body" ->
  esl '(for (var x 1) (< x 10) (++ x))'
    ..`@equals` "for (var x = 1; x < 10; ++x) {\n}"

test "for loop with null update" ->
  esl '(for (var x 1) (< x 10) () ((. console log) "ok")
                                ((. console log) "still ok"))'
    ..`@equals` "for (var x = 1; x < 10;) {\n    console.log('ok');\n    console.log('still ok');\n}"

test "for loop with null init, update and test" ->
  esl '(for () () () ((. console log) "ok")
                     ((. console log) "still ok"))'
    ..`@equals` "for (;;) {\n    console.log('ok');\n    console.log('still ok');\n}"

test "for-in loop with implicit body" ->
  esl '(forin (var x) xs ((. console log) x))'
    ..`@equals` "for (var x in xs) {\n    console.log(x);\n}"

test "for-in loop with explicit body" ->
  esl '(forin (var x) xs (block ((. console log) x)))'
    ..`@equals` "for (var x in xs) {\n    console.log(x);\n}"

test "multiple statements in program" ->
  esl '((. console log) "hello") ((. console log) "world")'
    ..`@equals` "console.log('hello');\nconsole.log('world');"

test "function with implicit block body" ->
  esl '(lambda (x) ((. console log) "hello") \
                   ((. console log) "world"))'
    ..`@equals` "(function (x) {\n    console.log(\'hello\');\n    console.log(\'world\');\n});"

test "function with explicit block body" ->
  esl '(lambda (x) (block
                      ((. console log) "hello") \
                      ((. console log) "world")))'
    ..`@equals` "(function (x) {\n    console.log(\'hello\');\n    console.log(\'world\');\n});"

test "new statement" ->
  esl '(new Error "hi") (new x)'
    ..`@equals` "new Error('hi');\nnew x();"

test "debugger statement" ->
  esl '(debugger)'
    ..`@equals` "debugger;"

test "throw statement" ->
  esl '(throw e)'
    ..`@equals` "throw e;"

test "try-catch (with `catch` and `finally`)" ->
  esl '''
      (try (yep)
           (nope)
           (catch err
                  (a err)
                  (b err))
           (finally (x)
                    (y)))
      '''
    ..`@equals` """
      try {
          yep();
          nope();
      } catch (err) {
          a(err);
          b(err);
      } finally {
          x();
          y();
      }
      """

test "try-catch (with plain atom in body)" ->
  esl '''
      (try foo
           (catch e
                  bar)
           (finally baz))
      '''
    ..`@equals` """
      try {
          foo;
      } catch (e) {
          bar;
      } finally {
          baz;
      }
      """

test "try-catch (with empty body, `catch` and `finally`)" ->
  esl '''
      (try (catch err)
           (finally))
      '''
    ..`@equals` """
      try {
      } catch (err) {
      } finally {
      }
      """

test "try-catch (with `catch` and `finally` as explicit blocks)" ->
  esl '''
      (try (yep)
           (nope)
           (catch err (block (a err) (b err)))
           (finally (block (x) (y))))
      '''
    ..`@equals` """
      try {
          yep();
          nope();
      } catch (err) {
          a(err);
          b(err);
      } finally {
          x();
          y();
      }
      """

test "try-catch (with `catch` and `finally` in opposite order)" ->
  esl '''
      (try (yep)
           (nope)
           (finally (x) (y))
           (catch err (a err) (b err)))
      '''
    ..`@equals` """
      try {
          yep();
          nope();
      } catch (err) {
          a(err);
          b(err);
      } finally {
          x();
          y();
      }
      """

test "try-catch (`catch`; no `finally`)" ->
  esl '''
      (try (yep)
           (nope)
           (catch err (a err) (b err)))
      '''
    ..`@equals` """
      try {
          yep();
          nope();
      } catch (err) {
          a(err);
          b(err);
      }
      """

test "try-catch (`finally`; no `catch`)" ->
  esl '''
      (try (yep)
           (nope)
           (finally (x) (y)))
      '''
    ..`@equals` """
      try {
          yep();
          nope();
      } finally {
          x();
          y();
      }
      """
test "quoting a list produces array" ->
  esl "'(1 2 3)"
    eval ..
      ..type `@equals` "list"
      ..values
        ..length `@equals` 3
        ..0
          ..type `@equals` "atom"
          ..value `@equals` "1"
        ..1
          ..type `@equals` "atom"
          ..value `@equals` "2"
        ..2
          ..type `@equals` "atom"
          ..value `@equals` "3"

test "quoting strings produces string AST object" ->
  esl "'\"hi\""
    eval ..
      ..type `@equals` "string"
      ..value `@equals` "hi"


test "quoting atoms produces an object representing it" ->
  esl "'fun"
    eval ..
      ..type `@equals` "atom"
      ..value `@equals` "fun"

test "simple quoting macro" ->
  esl "(macro random (lambda () (return '((. Math random)))))
       (+ (random) (random))"
    ..`@equals` "Math.random() + Math.random();"

test "macro constructor given object imports properties as macros" ->
  esl '''
      (macro (object a (lambda () (return '"hi a"))
                     b (lambda () (return '"hi b"))))
      (a) (b)
      '''
   ..`@equals` "'hi a';\n'hi b';"

test "simple unquoting macro" ->
  esl "(macro call (lambda (x) (return `(,x))))
       (call three)"
    ..`@equals` "three();"

test "empty-list-returning macro" ->
  esl "(macro shouldbenull (lambda () (return '())))
       (shouldbenull)"
    ..`@equals` "null;"

test "empty-list-returning macro (using quasiquote)" ->
  esl "(macro shouldbenull (lambda () (return `())))
       (shouldbenull)"
    ..`@equals` "null;"

test "nothing-returning macro" ->
  esl "(macro nothing (lambda () (return undefined)))
       (nothing)"
    ..`@equals` ""

test "macros mask others defined before with the same name" ->
  esl "(macro m (lambda () (return ())))
       (macro m (lambda () (return '((. console log) \"hi\"))))
       (m)"
    ..`@equals` "console.log('hi');"

test "macros can be masked in the current scope by assigning null" ->
  esl "(macro array)
       (array 1 2)"
    ..`@equals` "array(1, 2);"

test "macros can be defined inside function bodies" ->
  esl "(var f (lambda (x)
         (macro x (lambda () (return '5)))
         (return (x))))"
    ..`@equals` "var f = function (x) {\n    return 5;\n};"

test "macros go out of scope at the end of the nesting level" ->
  esl "(var f (lambda (x)
         (macro x (lambda () (return '5)))
         (return (x))))
       (x)"
    ..`@equals` "var f = function (x) {\n    return 5;\n};\nx();"

test "macro constructor given 2 atoms aliases the second to the first" ->
  esl "(macro list array)
       (list a 1 b 2)"
    ..`@equals` "[\n    a,\n    1,\n    b,\n    2\n];"

test "dead simple quasiquote" ->
  esl "(macro q (lambda () (return `(+ 2 3))))
       (q)"
    ..`@equals` "2 + 3;"

test "quasiquote is like quote if no unquotes contained" ->
  esl "(macro rand (lambda ()
                  (return `(* 5
                      ((. Math random))))))
       (rand)"
    ..`@equals` "5 * Math.random();"

test "macros can quasiquote to unquote arguments into output" ->
  esl "(macro rand (lambda (upper)
                  (return `(* ,upper
                      ((. Math random))))))
       (rand 5)"
    ..`@equals` "5 * Math.random();"

test "macro env can create atoms out of strings or numbers" ->
  esl """
      (macro m (lambda () (return ((. this atom) 42))))
      (m)"""
    ..`@equals` "42;"

test "macro env can create sexpr AST nodes equivalently to quoting" ->
  with-quote =
    esl """
        (macro m (lambda () (return '(a \"b\"))))
        (m)"""
  with-construct =
    esl """
        (macro m (lambda ()
                  (return ((. this list)
                           ((. this atom) "a")
                           ((. this string) "b")))))
        (m)"""
  with-quote `@equals` with-construct

test "macros can evaluate number arguments to JS and convert them back again" ->
  esl """
       (macro incrementedTimesTwo (lambda (x)
                    (var y (+ 1 ((. this evaluate) x)))
                    (var xAsSexpr ((. this atom) ((. y toString))))
                    (return `(* ,xAsSexpr 2))))
       (incrementedTimesTwo 5)
       """
    ..`@equals` "6 * 2;"

test "macros can evaluate object arguments" ->
  # This macro uses this.evaluate to compile and evaluate a list that expands
  # to an object, then stringifies it.
  esl """
       (macro objectAsString (lambda (input)
                    (= obj ((. this evaluate) input))
                    (return ((. this string) ((. JSON stringify) obj)))))
       (objectAsString (object a 1))
       """
    ..`@equals` "'{\"a\":1}';"

test "macros can evaluate statements" ->
  # This macro uses this.evaluate to compile and run an if-statement.  A
  # statement does not evaluate to a value, so we check for undefined.
  esl """
       (macro evalThis (lambda (input)
                    (= obj ((. this evaluate) input))
                    (if (=== obj undefined)
                        (return ((. this atom) "yep"))
                        (return ((. this atom) "nope")))))
       (evalThis (if 1 (block) (block)))
       """
    ..`@equals` "yep;"

test "macros can unquote arrays into quasiquoted lists (non-splicing)" ->
  esl "(macro what (lambda (x)
                  (return `(,x))))
       (what (+ 2 3))"
    ..`@equals` "(2 + 3)();"

test "macros can splice arrays into quasiquoted lists" ->
  esl "(macro sumOf (lambda (xs) (return `(+ ,@xs))))
       (sumOf (1 2 3))"
    ..`@equals` "1 + (2 + 3);"

test "macros can splice in empty arrays" ->
  esl "(macro sumOf (lambda (xs) (return `(+ 1 2 ,@xs))))
       (sumOf ())"
    ..`@equals` "1 + 2;"

test "quasiquote can contain nested lists" ->
  esl '''
      (macro mean
       (lambda ()
        ; Convert arguments into array
        (var args
             ((. this list apply) null ((. Array prototype slice call) arguments 0)))
        (var total ((. this atom) ((. (. args values length) toString))))
        (return `(/ (+ ,@args) ,total))))
       (mean 1 2 3)
      '''
    ..`@equals` "(1 + (2 + 3)) / 3;"

test "array macro produces array expression" ->
  esl "(array 1 2 3)"
    ..`@equals` "[\n    1,\n    2,\n    3\n];"

test "array macro can be empty" ->
  esl "(array)"
    ..`@equals` "[];"

test "object macro produces object expression" ->
  esl "(object a 1 b 2)"
    ..`@equals` "({\n    a: 1,\n    b: 2\n});"

test "object macro can be passed strings as keys too" ->
  esl '(object "a" 1 "b" 2)'
    ..`@equals` "({\n    'a': 1,\n    'b': 2\n});"

test "object macro's value parts can be expressions" ->
  esl '(object "a" (+ 1 2) "b" (f x))'
    ..`@equals` "({\n    'a': 1 + 2,\n    'b': f(x)\n});"
# dynamic *keys* would be ES6

test "macro producing an object literal" ->
  esl "(macro obj (lambda () (return '(object a 1))))
       (obj)"
    ..`@equals` "({ a: 1 });"

test "macro producing a function" ->
  esl "(macro increase (lambda (n)
                      (return `(lambda (x) (return (+ x ,n))))))
       (increase 3)"
    ..`@equals` "(function (x) {\n    return x + 3;\n});"

test "property access (dotting) chains identifiers" ->
  esl "(. a b c)"
    ..`@equals` "a.b.c;"

test "property access (dotting) chains literals" ->
  esl "(. a 1 2)"
    ..`@equals` "a[1][2];"

test "property access (dotting) can be nested" ->
  esl "(. a (. a (. b name)))"
    ..`@equals` "a[a[b.name]];"

test "property access (dotting) chains mixed literals and identifiers" ->
  esl "(. a b 2 a)"
    ..`@equals` "a.b[2].a;"

test "property access (dotting) treats strings as literals, not identifiers" ->
  esl "(. a \"hi\")"
    ..`@equals` "a['hi'];"

test "computed member expression (\"square brackets\")" ->
  esl "(get a b 5)"
    ..`@equals` "a[b][5];"

test "regex literal" ->
  esl '(regex ".*")'
    ..`@equals` "/.*/;"

test "regex literal with flags" ->
  esl '(regex ".*" "gm")'
    ..`@equals` "/.*/gm;"

test "regex literals are escaped" ->
  esl '(regex "/.\\"*")'
    ..`@equals` "/\\/.\"*/;"

test "regex literals can be derived from atoms too" ->
  esl '(regex abc.* g)'
    ..`@equals` "/abc.*/g;"

test "regex can be given atoms with escaped spaces and slashes" ->
  esl '(regex abc\\ */ g)'
    ..`@equals` "/abc *\\//g;"

test "macro deliberately breaking hygiene for function argument anaphora" ->
  esl "(macro : (lambda (body)
       (return `(lambda (it) ,body))))
        (: (return (. it x)))"
    ..`@equals` "(function (it) {\n    return it.x;\n});"

test "macro given nothing produces no output" ->
  esl "(macro null)"
   ..`@equals` ""
  esl "(macro undefined)"
   ..`@equals` ""

test "when returned from an IIFE, macros can share state" ->
  esl """
      (macro
       ((lambda () (var x 0)
        (return (object
                 plusPrev  (lambda (n)
                                   (+= x ((. this evaluate) n))
                                   (return ((. this atom) ((. x toString)))))
                 timesPrev (lambda (n)
                                   (*= x ((. this evaluate) n))
                                   (return ((. this atom) ((. x toString))))))))))
      (plusPrev 2) (timesPrev 2)
       """
   ..`@equals` "2;\n4;"

test "error thrown by macro is caught with a descriptive message" ->

  tests =
    * code : """
             (macro x (lambda () (throw (Error "aaah"))))
             (x)
             """
      desired-error : "Error evaluating macro `x` (called at line 2, column 0): aaah"
    * code : """
             (macro x (lambda () (m)))
             (x)
             """
      desired-error : "Error evaluating macro `x` (called at line 2, column 0): m is not defined"

  tests.for-each (it, i) ~>
    caught = false
    try
      esl it.code
    catch e
      caught := true
      if e.message isnt it.desired-error
        @fail "Code #i produced wrong error message"
    finally
      if not caught
        @fail "Code #i did not throw an error (expected it to)"
      @pass!

test "macro constructor called with no arguments is an error" ->
  -> esl "(macro)"
   ..`@throws` Error

test "macro constructor loading from IIFE can load nothing" ->
  esl """
      (macro ((lambda ())))
       """
   ..`@equals` ""

test "macro can return multiple statements by returning an array" ->
  esl "(macro declareTwo (lambda () (return (array '(var x 0) '(var y 1)))))
       (declareTwo)"
   ..`@equals` "var x = 0;\nvar y = 1;"

test "macro can check argument type and get its value" ->
  esl '''
      (macro stringy (lambda (x)
       (if (== (. x type) "atom")
        (return ((. this string) (+ "atom:" (. x value))))
        (block
         (if (== (. x type) "string")
          (return x)
          (return "An unexpected development!"))))))
      (stringy a)
      (stringy "b")
      '''
    ..`@equals` "'atom:a';\n'b';"

test "macro returning atom with empty or null name fails" ->
  self = this
  <[ "" null undefined ]>.for-each ->
    self.throws do
      -> esl """
          (macro mac (lambda () (return ((. this atom) #it))))
          (mac)
          """
      Error

test "require in macros is relative to the eslisp file" ->

  { exec-sync } = require \child_process

  { name : root-dir, fd } = tmp.dir-sync!

  # Create simple module in the root to import as a macro
  module-basename = "#{uuid.v4!}.js"
  module-path = path.join root-dir, module-basename
  module-fd = fs.open-sync module-path, \a+
  fs.write-sync module-fd, '''
    module.exports = function() {
      return this.string("BOOM SHAKALAKA")
    }
    '''

  # Create an eslisp file in the root that requires the root directory module
  # as a macro
  main-basename = "#{uuid.v4!}.js"
  main-path = path.join root-dir, main-basename
  main-fd = fs.open-sync main-path, \a+
  fs.write-sync main-fd, """
    (macro (object x (require "./#module-basename")))
    (x)
    """
  # Create a subdirectory
  subdir-basename = "subdir"
  subdir-path = path.join root-dir, subdir-basename
  fs.mkdir-sync subdir-path

  # Create an eslisp file in the sub-directory that requires the module in the
  # root directory (its parent directory) as a macro
  main2-basename = "#{uuid.v4!}.js"
  main2-path = path.join subdir-path, main2-basename
  main2-fd = fs.open-sync main2-path, \a+
  fs.write-sync main2-fd, """
    (macro (object x (require "../#module-basename")))
    (x)
    """

  eslc-path = path.join process.cwd!, "bin/eslc"
  try
    # Call the eslisp compiler with current working directory set to the root
    # directory, with both eslisp files in turn, and expect neither to error.
    exec-sync "#eslc-path #main-basename", cwd : root-dir
      ..to-string! `@equals` "'BOOM SHAKALAKA';\n"
    exec-sync "#eslc-path #main2-path", cwd : root-dir
      ..to-string! `@equals` "'BOOM SHAKALAKA';\n"
    # This second one will only succeed if `require` within macros works
    # relative to the eslisp file being compiled.
  finally
    e <~ rimraf root-dir
    @equals e, null

test "macros can be required from node_modules relative to root directory" ->

  # Create dummy temporary package

  module-name = "test-#{uuid.v4!}"
  dir = "./node_modules/#module-name"
  fs.mkdir-sync dir
  fd = fs.open-sync "#dir/index.js" \a+
  fs.write-sync fd, "module.exports = function() { }"

  fd = fs.open-sync "#dir/package.json" \a+
  fs.write-sync fd, """
  {
    "name": "#module-name",
    "version": "0.1.0",
    "description": "test-generated module; safe to delete",
    "main": "index.js",
    "dependencies": {
    }
  }
  """

  # Attempt to require it and use it as a macro

  esl """
    (macro (object x (require "#module-name")))
    (x)
    """
    ..`@equals` ""

  e <- rimraf dir

test "macros required from separate modules can access complation env" ->

  # To set up, create a temporary file with the appropriate macro contents
  { name, fd } = tmp.file-sync!
  fs.write-sync fd, """
    module.exports = function() {
      // Return two statements: a string and a generated symbol
      return [
        this.atom("ok"),
        this.atom("ok2")
      ];
    };
    """

  code = esl """
    (macro (object x (require "#name")))
    (x)
    """

  code.split "\n"
    ..length `@equals` 2
    ..0 `@equals` "ok;"
    ..1 `@equals` "ok2;"

  fs.unlink-sync name # clean up

test "macro function can be returned from IIFE" ->
  # IIFE = immediately-invoked function expression
  #
  # Note how the outer function is wrapped in another set of parens to
  # immediately call it.  It returns another function, and *that* becomes the
  # macro.
  esl '''
    (macro say-hi ((lambda ()
      (return (lambda () (return '"hi"))))))
    (say-hi)
    '''
    ..`@equals` "'hi';"

test "IIFE given to macro can itself contain other macros" ->
  esl '''
    (macro say-hi ((lambda ()
      (macro x (lambda() (return ''"hi")))
      (return (lambda () (return (x)))))))
    (say-hi)
    '''
    ..`@equals` "'hi';"

test "macro-generating macro" -> # yes srsly
  esl '''
    (macro define-with-name (lambda (x)
      (return `(macro ,x (lambda () (return `(var hello 5)))))))
    (define-with-name what)
    (what)
    '''
    ..`@equals` "var hello = 5;"

test "macro generating macro and macro call" -> # yes srsly squared
  esl '''
    (macro define-and-call (lambda (x)
      (return (array `(macro what (lambda () (return `(hello))))
                     `(what)))))
    (define-and-call)
    '''
    ..`@equals` "hello();"

test "macros capture from outer env" ->
  esl '''
    (macro f (lambda () (return '"hello")))
    (macro g (lambda () (return '(f))))
    (g)
    '''
    ..`@equals` "'hello';"

test "macros allow redefinition of captured macros" ->
  # Later redefinitions in a macro's scope do take effect.
  esl '''
    (macro say (lambda () (return '(no))))
    (macro m   (lambda () (return '(say))))
    (macro say (lambda () (return '(yes))))
    (m)
    '''
    ..`@equals` "yes();"

test "invalid AST returned by macro throws error" ->
  @throws do
    ->
      # `console.log` is invalid as a variable name, but if used as if it were
      # one, without checking if the AST makes sense, this will compile to
      # valid JavaScript code of `console.log('hi');`!
      esl '''
        (macro hack (lambda () (return '(console.log "hi"))))
        (hack)
        '''
    Error

test "macro multi-returning with bad values throws descriptive error" ->
  try
    esl '''
      (macro breaking (lambda () (return (array null))))
      (breaking)
      '''
  catch e
    e.message `@equals` "Unexpected `Null` value received in multi-return"
    return

  @fail!

test "macro return intermediates may be invalid if fixed by later macro" ->
  # `...` is an invalid variable name, but since it's corrected by a later
  # macro before evaluation, that's fine.
  esl '''
    (macro callDots (lambda () (return '(...))))
    (macro replaceDots (lambda () (return 'x)))
    (replaceDots (callDots))
    '''
      ..`@equals` "x;"

test "macro can return estree object" ->
  esl '''
    (macro identifier (lambda ()
      (return (object "type" "Identifier"
                      "name" "x"))))
    (identifier)
    '''
      ..`@equals` "x;"

test "macro can multi-return estree objects" ->
  esl '''
    (macro identifiers (lambda ()
      (return (array
               (object "type" "Identifier"
                       "name" "x")
               (object "type" "Identifier"
                       "name" "y")))))
    (identifiers)
    '''
      ..`@equals` "x;\ny;"

test "macro can multi-return a combination of estree and sexprs" ->
  esl '''
    (macro identifiers (lambda ()
      (return (array
               (object "type" "Identifier"
                       "name" "x")
               'x))))
    (identifiers)
    '''
      ..`@equals` "x;\nx;"

test "macro can compile and return parameter as estree" ->
  esl '''
    (macro that (lambda (x)
      (return ((. this compile) x))))
    (that 3)
    (that "hi")
    (that (c))
    (that (object a b))
    '''
      ..`@equals` "3;\n'hi';\nc();\n({ a: b });"

test "multiple invocations of the compiler are separate" ->
  esl "(macro what (lambda () (return 'hi)))"
  esl "(what)"
    .. `@equals` "what();" # instead of "hi;"

test "transform-macro can replace contents" ->
  wrapper = ->
    @list do
      @atom \*
      @atom \3
      @atom \4
  esl "(+ 1 2)" transform-macros : [ wrapper ]
    .. `@equals` "3 * 4;"

test "transform-macro can return null" ->
  wrapper = -> null
  esl "(+ 1 2)" transform-macros : [ wrapper ]
    .. `@equals` ""

test "transform-macro can return empty array" ->
  wrapper = -> []
  esl "(+ 1 2)" transform-macros : [ wrapper ]
    .. `@equals` ""

test "transform-macro can receive arguments" ->
  wrapper = (...args) ->
    @list.apply null [ @atom "hi" ].concat args
  esl "(+ 1 2) (+ 3 4)" transform-macros : [ wrapper ]
    .. `@equals` "hi(1 + 2, 3 + 4);"

test "transform-macro can multi-return" ->
  wrapper = (...args) ->
    [ (@atom \hi), (@atom "yo") ]
  esl "" transform-macros : [ wrapper ]
    .. `@equals` "hi;\nyo;"

test "multiple transform-macros can be used" ->
  wrapper-passthrough = (...args) -> args
  esl "(+ 1 2)" transform-macros : [ wrapper-passthrough, wrapper-passthrough ]
    .. `@equals` "1 + 2;"

test "multiple transform-macros are applied in order" ->
  wrap1 = (...args) -> @list.apply null [ @atom \one ].concat args
  wrap2 = (...args) -> @list.apply null [ @atom \two ].concat args
  wrap3 = (...args) -> @list.apply null [ @atom \three ].concat args
  esl "zero" transform-macros : [ wrap1, wrap2, wrap3 ]
    .. `@equals` "three(two(one(zero)));"

test "identifier source map" ->
  { code, map } = esl.with-source-map "x" filename : "test.esl"

  code `@equals` "x;"

  map := JSON.parse map
    ..version `@equals` 3
    ..sources.length `@equals` 1
    ..sources-content.length `@equals` 1

  consume-map map
    ..original-position-for line : 1 column : 0
      ..line `@equals` 1
      ..column `@equals` 0
      ..name `@equals` \x

test "identifier source map (with leading spaces)" ->
  { code, map } = esl.with-source-map "   x" filename : "test.esl"

  code `@equals` "x;"

  map := JSON.parse map
    ..version `@equals` 3
    ..sources.length `@equals` 1
    ..sources-content.length `@equals` 1

  consume-map map
    ..original-position-for line : 1 column : 0
      ..line `@equals` 1
      ..column `@equals` 3
      ..name `@equals` \x


test "boolean literal source map" ->

  { code, map } = esl.with-source-map "true" filename : "test.esl"

  code `@equals` "true;"

  map := JSON.parse map
    ..version `@equals` 3
    ..sources.length `@equals` 1
    ..sources-content.length `@equals` 1

  consume-map map
    ..original-position-for line : 1 column : 0
      ..line `@equals` 1
      ..column `@equals` 0
      @not-ok ..name

test "number literal source map" ->

  { code, map } = esl.with-source-map "42" filename : "test.esl"

  code `@equals` "42;"

  map := JSON.parse map
    ..version `@equals` 3
    ..sources.length `@equals` 1
    ..sources-content.length `@equals` 1

  consume-map map
    ..original-position-for line : 1 column : 0
      ..line `@equals` 1
      ..column `@equals` 0
      @not-ok ..name

test "string literal source map" ->

  { code, map } = esl.with-source-map '"hello"' filename : "test.esl"

  code `@equals` "'hello';"

  map := JSON.parse map
    ..version `@equals` 3
    ..sources.length `@equals` 1
    ..sources-content.length `@equals` 1

  consume-map map
    ..original-position-for line : 1 column : 0
      ..line `@equals` 1
      ..column `@equals` 0
      @not-ok ..name

test "call expression source map" ->

  { code, map } = esl.with-source-map '(f a b)' filename : "test.esl"

  code `@equals` "f(a, b);"

  map := JSON.parse map
    ..version `@equals` 3
    ..sources.length `@equals` 1
    ..sources-content.length `@equals` 1
    ..names `@deep-equals` <[ f a b ]>

  consume-map map
    ..original-position-for line : 1 column : 0
      ..line `@equals` 1
      ..column `@equals` 1
      ..name `@equals` \f
    ..original-position-for line : 1 column : 2
      ..line `@equals` 1
      ..column `@equals` 3
      ..name `@equals` \a
    ..original-position-for line : 1 column : 5
      ..line `@equals` 1
      ..column `@equals` 5
      ..name `@equals` \b

test "macro return source map" ->

  { code, map } = esl.with-source-map '(+ a b)' filename : "test.esl"

  code `@equals` "a + b;"

  map := JSON.parse map
    ..version `@equals` 3
    ..sources.length `@equals` 1
    ..sources-content.length `@equals` 1
    ..names `@deep-equals` <[ a b ]>

  consume-map map
    ..original-position-for line : 1 column : 0
      ..line `@equals` 1
      ..column `@equals` 3
      ..name `@equals` \a
    ..original-position-for line : 1 column : 2
      ..line `@equals` 1
      ..column `@equals` 1
      @not-ok ..name
    ..original-position-for line : 1 column : 4
      ..line `@equals` 1
      ..column `@equals` 5
      ..name `@equals` \b

test "macro return source map (across multiple lines)" ->

  { code, map } = esl.with-source-map '(+\na\nb)' filename : "test.esl"

  code `@equals` "a + b;"

  map := JSON.parse map
    ..version `@equals` 3
    ..sources.length `@equals` 1
    ..sources-content.length `@equals` 1
    ..names `@deep-equals` <[ a b ]>

  consume-map map
    ..original-position-for line : 1 column : 0
      ..line `@equals` 2
      ..column `@equals` 0
      ..name `@equals` \a
    ..original-position-for line : 1 column : 2
      ..line `@equals` 1
      ..column `@equals` 1
      @not-ok ..name
    ..original-position-for line : 1 column : 4
      ..line `@equals` 3
      ..column `@equals` 0
      ..name `@equals` \b

test-async "macros can be defined when eslisp is used from the Node REPL" ->
  @plan 2
  # Spawn a new Node.js REPL process
  spawn "node"
    # Feed it some input:
    ..stdin
      # Require the eslisp module in it
      ..write "eslisp = require('.')\n"
      # Create a stateful eslisp compiler instance
      ..write "x = eslisp.stateful()\n"
      # Define a macro in it
      ..write "x('(macro x (lambda () (return \\'42)))')\n"
      # Call that macro, and log the resulting JavaScript code
      ..write "console.log(x('(x)'))\n"
      ..end!
    ..stdout.pipe concat (.to-string! `@equals` '42;\n')
    ..stderr.pipe concat (.to-string! `@equals` '')
    ..on \close ~> @end!

test-async "macros can be required from eslisp in Node REPL relative to REPL cwd" ->

  { name : dir-name, fd } = tmp.dir-sync!

  # Create dummy temporary file
  module-basename = "#{uuid.v4!}.js"
  module-path = path.join dir-name, module-basename
  module-fd = fs.open-sync module-path, \a+
  fs.write-sync module-fd, '''
    module.exports = function() {
      return this.atom(42)
    }
    '''

  @plan 4

  spawn "node" cwd : dir-name
    # Feed it some input:
    ..stdin
      # Require the eslisp module in it
      ..write "eslisp = require('#{process.cwd!}')\n"
      # Create a stateful eslisp compiler instance
      ..write "x = eslisp.stateful()\n"
      # Define a macro in it
      ..write "x('(macro x (require \"./#module-basename\"))')\n"
      # Call that macro, and log the resulting JavaScript code
      ..write "console.log(x('(x)'))\n"
      ..end!
    ..stdout.pipe concat (.to-string! `@equals` '42;\n')
    ..stderr.pipe concat (.to-string! `@equals` '')
    ..on \close ~>
      @pass "Node.js process exited"
      e <~ rimraf dir-name
      @equals e, null, "Temporary directory removed"
