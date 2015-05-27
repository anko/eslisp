#!/usr/bin/env lsc
test = (name, test-func) ->
  (require \tape) name, (t) ->
    test-func.call t  # Make `this` refer to tape's asserts
    t.end!            # Automatically end tests

esl = require \./src/index.ls

{ unique } = require \prelude-ls

test "nothing" ->
  esl ""
    .. `@equals` ""

test "plain comment" ->
  esl "\n; nothing\n"
    ..`@equals` ""

test "first-line shebang" ->
  esl "#!something goes here\n(hello)\n"
    ..`@equals` "hello();"

test "plain literal" ->
  esl "3"
    ..`@equals` "3;"

test "plain somewhat number-looking variable" ->
  esl "3asd5"
    ..`@equals` "3asd5;"

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
  esl "(* 2)"
    ..`@throws` Error

test "n-ary division" ->
  esl "(/ 1 2 3)"
    ..`@equals` "1 / (2 / 3);"

test "unary division is invalid" ->
  esl "(/ 2)"
    ..`@throws` Error

test "n-ary modulus" ->
  esl "(% 1 2 3)"
    ..`@equals` "1 % (2 % 3);"

test "increment-after expression" ->
  esl "(_++ x)"
    ..`@equals` "x++;"

test "increment-before expression" ->
  esl "(++_ x) (++ x)"
    ..`@equals` "++x;\n++x;"

test "decrement-after expression" ->
  esl "(_-- x)"
    ..`@equals` "x--;"

test "decrement-before expression" ->
  esl "(--_ x) (-- x)"
    ..`@equals` "--x;\n--x;"

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
  esl "(function (x) (return (+ x 1)))"
    ..`@equals` "(function (x) {\n    return x + 1;\n});"

test "function with no arguments" ->
  esl "(function () (return 1))"
    ..`@equals` "(function () {\n    return 1;\n});"

test "assignment expression" -> # += and whatever are same code path
  esl "(:= f (function (x) (return (+ x 1))))"
    ..`@equals` "f = function (x) {\n    return x + 1;\n};"

test "variable declaration statement" ->
  esl "(= f)"
    ..`@equals` "var f;"

test "variable declaration and assignment" ->
  esl "(= f (function (x) (return (+ x 1))))"
    ..`@equals` "var f = function (x) {\n    return x + 1;\n};"

test "empty statement" ->
  esl "()"
    ..`@equals` ";"

test "break and continue statements" ->
  esl "(break) (continue)"
    ..`@equals` "break;\ncontinue;"

test "return statement" ->
  esl "(return \"hello there\")"
    ..`@equals` "return 'hello there';"

test "member expression" ->
  esl "(. console log)"
    ..`@equals` "console.log;"

test "call expression" ->
  esl "(f)"
    ..`@equals` "f();"

test "member, then call with arguments" ->
  esl '((. console log) "hi")'
    ..`@equals` "console.log('hi');"

test "func with member and call in it" ->
  esl "(function (x) ((. console log) x))"
    ..`@equals` "(function (x) {\n    console.log(x);\n});"

test "switch statement" ->
  esl '''
      (switch (y)
              ((== x 5) ((. console log) "hi") (break))
              (default  (return false)))
      '''
    ..`@equals` """
                switch (y()) {
                case x == 5:
                    console.log('hi');
                    break;
                default:
                    return false;
                }
                """

test "if-statement" ->
  esl '(if (+ 1 0) (((. console log) "yes") (x)) (((. console error) "no")))'
    ..`@equals` """
      if (1 + 0) {
          console.log(\'yes\');
          x();
      } else {
          console.error(\'no\');
      }
      """

test "if-statement without alternate" ->
  esl '(if (+ 1 0) (((. console log) "yes") (x)))'
    ..`@equals` """
      if (1 + 0) {
          console.log(\'yes\');
          x();
      }
      """

test "ternary expression" ->
  esl '(?: "something" 0 1)'
    ..`@equals` "'something' ? 0 : 1;"

test "while loop" ->
  esl '(while (-- n) ((. console log) "ok")
                     ((. console log) "still ok"))'
    ..`@equals` "while (--n) {\n    console.log('ok');\n    console.log('still ok');\n}"

test "do/while loop" ->
  esl '(dowhile (-- n) ((. console log) "ok")
                     ((. console log) "still ok"))'
    ..`@equals` "do {\n    console.log('ok');\n    console.log('still ok');\n} while (--n);"

test "for loop" ->
  esl '(for (= x 1) (< x 10) (++ x) ((. console log) "ok")
                                    ((. console log) "still ok"))'
    ..`@equals` "for (var x = 1; x < 10; ++x) {\n    console.log('ok');\n    console.log('still ok');\n}"

test "for loop with no body" ->
  esl '(for (= x 1) (< x 10) (++ x))'
    ..`@equals` "for (var x = 1; x < 10; ++x) {\n}"

test "for loop with null update" ->
  esl '(for (= x 1) (< x 10) () ((. console log) "ok")
                                ((. console log) "still ok"))'
    ..`@equals` "for (var x = 1; x < 10; ;) {\n    console.log('ok');\n    console.log('still ok');\n}"

test "for loop with null init, update and test" ->
  esl '(for () () () ((. console log) "ok")
                     ((. console log) "still ok"))'
    ..`@equals` "for (;; ;; ;) {\n    console.log('ok');\n    console.log('still ok');\n}"

test "for-in loop" ->
  esl '(forin (= x) xs ((. console log) x))'
    ..`@equals` "for (var x in xs) {\n    console.log(x);\n}"

test "multiple statements in program" ->
  esl '((. console log) "hello") ((. console log) "world")'
    ..`@equals` "console.log('hello');\nconsole.log('world');"

test "multiple statements in function" ->
  esl '(function (x) ((. console log) "hello") \
                   ((. console log) "world"))'
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
      (try
       ((yep) (nope))
       (catch err
        (a err) (b err))
       (finally (x) (y)))
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
      (try
       ((yep) (nope))
       (finally (x) (y))
       (catch err
        (a err) (b err)))
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
      (try
       ((yep) (nope))
       (catch err
        (a err) (b err)))
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
      (try
       ((yep) (nope))
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
#test "quoting a list produces array" ->
#  esl "'(1 2 3)"
#    ..`@equals` "[\n    1,\n    2,\n    3\n];"
#
#test "quoting numbers produces numbers" ->
#  esl "'(1)"
#    ..`@equals` "[1];"
#
#test "quoting strings produces strings" ->
#  esl "'(\"hi\")"
#    ..`@equals` "['hi'];"
#
#test "quoting atoms produces an object representing it" ->
#  esl "'(fun)"
#    ..`@equals` "[{\n        \'type\': \'atom\',\n        \'text\': \'fun\'\n    }];"

test "simple quoting macro" ->
  esl "(macro random () (return '((. Math random))))
       (+ (random) (random))"
    ..`@equals` "Math.random() + Math.random();"

test "simple non-quoting macro" ->
  esl "(macro three () (return `,(+ 1 2)))
       (three)"
    ..`@equals` "3;"

test "empty-list-returning macro" ->
  esl "(macro nothing () (return '()))
       (nothing)"
    ..`@equals` ";"

test "empty-list-returning macro using quasiquote" ->
  esl "(macro nothing () (return `()))
       (nothing)"
    ..`@equals` ";"

test "null-returning macro" ->
  esl "(macro nothing () (return undefined))
       (nothing)"
    ..`@equals` ""

test "macros mask others defined before with the same name" ->
  esl "(macro m () (return ()))
       (macro m () (return '((. console log) \"hi\")))
       (m)"
    ..`@equals` "console.log('hi');"

test "macros can be defined inside function bodies" ->
  esl "(= f (function (x)
         (macro x () (return 5))
         (return (x))))"
    ..`@equals` "var f = function (x) {\n    return 5;\n};"

test "macros go out of scope at the end of the nesting level" ->
  esl "(= f (function (x)
         (macro x () (return 5))
         (return (x))))
       (x)"
    ..`@equals` "var f = function (x) {\n    return 5;\n};\nx();"

test "dead simple quasiquote" ->
  esl "(macro q () (return `(+ 2 3)))
       (q)"
    ..`@equals` "2 + 3;"

test "quasiquote is like quote if no unquotes contained" ->
  esl "(macro rand ()
                  (return `(* 5
                      ((. Math random)))))
       (rand)"
    ..`@equals` "5 * Math.random();"

test "macros can quasiquote to unquote arguments into output" ->
  esl "(macro rand (upper)
                  (return `(* ,upper
                      ((. Math random)))))
       (rand 5)"
    ..`@equals` "5 * Math.random();"

test "macros can unquote modified arguments too" ->
  esl "(macro rand (upper)
                  (= x (* 2
                          (evaluate upper)))
                  (return `(* ,x ((. Math random)))))
       (rand 5)"
    ..`@equals` "10 * Math.random();"


test "macros can evaluate arguments and operate on them further" ->
  esl "(macro increment (x)
                  (return (+ 1 (evaluate x))))
       (increment 1)"
    ..`@equals` "2;"

test "macros can unquote arrays into quasiquoted lists (non-splicing)" ->
  esl "(macro what (x)
                  (return `(,x)))
       (what (+ 2 3))"
    ..`@equals` "(2 + 3)();"

test "macros can splice arrays into quasiquoted lists" ->
  esl "(macro sumOf (xs) (return `(+ ,@xs)))
       (sumOf (1 2 3))"
    ..`@equals` "1 + (2 + 3);"

test "array macro produces array expression" ->
  esl "(array 1 2 3)"
    ..`@equals` "[\n    1,\n    2,\n    3\n];"

test "object macro produces object expression" ->
  esl "(object a 1 b 2)"
    ..`@equals` "({\n    a: 1,\n    b: 2\n});"

test "object macro can be passed strings as keys too" ->
  esl '(object "a" 1 "b" 2)'
    ..`@equals` "({\n    'a': 1,\n    'b': 2\n});"

test "macro producing an object won't get confused for atom" ->
  esl "(macro obj () (return '(object a 1)))
       (obj)"
    ..`@equals` "({ a: 1 });"

test "macro producing a function" ->
  esl "(macro increase (n)
                      (return `(function (x) (return (+ x ,n)))))
       (increase 3)"
    ..`@equals` "(function (x) {\n    return x + 3;\n});"

test "macros can operate on their arguments variable" ->
  esl "(macro functionBackwards ()
        (= body (. arguments 0))
        (= args ((. Array prototype slice call) arguments 1))
        (return `(function ,@args ,body)))
       (functionBackwards (return (+ x 1)) (x))"
    ..`@equals` "(function (x) {\n    return x + 1;\n});"

test "property access (dotting) chains identifiers" ->
  esl "(. a b c)"
    ..`@equals` "a.b.c;"

test "property access (dotting) chains literals" ->
  esl "(. a 1 2)"
    ..`@equals` "a[1][2];"

test "property access (dotting) chains mixed literals and identifiers" ->
  esl "(. a b 2 a)"
    ..`@equals` "a.b[2].a;"

test "property access (dotting) treats stringa as literals, not identifiers" ->
  esl "(. a \"hi\")"
    ..`@equals` "a['hi'];"

test "computed member expression (\"square brackets\")" ->
  esl "(get a b 5)"
    ..`@equals` "a[b][5];"

test "macro deliberately breaking hygiene for function argument anaphora" ->
  esl "(macro : (body)
       (return `(function (it) ,body)))
        (: (return (. it x)))"
    ..`@equals` "(function (it) {\n    return it.x;\n});"

test "empty macros block produces no output" ->
  esl "(macros)"
   ..`@equals` ""

test "macros creates block invoked as function, return val forms macros" ->
  esl """
      (macros
        (= x 0)
        (return (object plusPrev  (function (n) (return (+= x (evaluate n)) x))
                        timesPrev (function (n) (return (*= x (evaluate n)) x)))))
      (plusPrev 2) (timesPrev 2)
       """
   ..`@equals` "2;\n4;"

test "macro can return multiple statements with `multi`" ->
  esl "(macro declareTwo () (return (multi '(= x 0) '(= y 1))))
       (declareTwo)"
   ..`@equals` "var x = 0;\nvar y = 1;"

test "macro can ask for atom/string argument type and get text" ->
  esl '''
      (macro stringy (x)
       (switch true
        ((isAtom x)   (return `,(+ "atom:" (textOf x))))
        ((isString x) (return `,(textOf x)))))
      (stringy a)
      (stringy "b")
      '''
   ..`@equals` "'atom:a';\n'b';"

test "macro can generate symbol with unique name" ->
  code = esl '''
    (macro declare ()
     (return `(= ,(gensym) null)))
    (declare)
    (declare)
    (declare)
    '''

  # The exact symbols generated are irrelevant here.  If they're unique,
  # they're OK.

  lines = code.split "\n"
    ..length `@equals` 3
  identifiers = lines.map (.match /var (.*) = null;/ .1)
    ..every -> it?                         # all matched
    (unique identifiers) `@deep-equals` .. # all were unique

test "macro can create implicit last-expr returning function shorthand" ->
  esl '''
    (macro fn ()
     (= args ((. Array prototype slice call) arguments))
     (= fnArgs (. args  0))
     (= fnBody ((. args slice) 1))

     (= last ((. fnBody pop)))

     (= lastConverted
      (?: (isExpr last)
          `(return ,last)
          last))

     ((. fnBody push) lastConverted)

     (return `(function ,fnArgs ,@fnBody)))

    (fn (x) (+ x 1))
    (fn (x) (= x 1))
    '''
    ..`@equals` """
      (function (x) {
          return x + 1;
      });
      (function (x) {
          var x = 1;
      });
      """

test "macro-generating macro" -> # yes srsly
  esl '''
    (macro define-with-name (x)
      (return `(macro ,x () (return `(hello)))))
    (define-with-name what)
    (what)
    '''
    ..`@equals` "hello();"

test "macros are referentially transparent" ->
  esl '''
    (macro say () (return '(yes))) ; define macro "say"
    (macro m   () (return `(say))) ; use "say" in another macro "m"
    (macro say () (return '(no)))  ; redefine macro "say"
    (m)                            ; call macro "m"
    '''
    ..`@equals` "yes();"

test "multiple invocations of the compiler are separate" ->
  esl "(macro what () (return 'hi))"
  esl "(what)"
    .. `@equals` "what();" # instead of "hi;"
