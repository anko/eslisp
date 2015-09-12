#!/usr/bin/env lsc
test = (name, test-func) ->
  (require \tape) name, (t) ->
    test-func.call t  # Make `this` refer to tape's asserts
    t.end!            # Automatically end tests

esl = require \./src/index.ls

{ unique } = require \prelude-ls
require! <[ tmp fs uuid rimraf path ]>

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
    ..`@equals` ""

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
    ..`@equals` "for (var x = 1; x < 10;) {\n    console.log('ok');\n    console.log('still ok');\n}"

test "for loop with null init, update and test" ->
  esl '(for () () () ((. console log) "ok")
                     ((. console log) "still ok"))'
    ..`@equals` "for (;;) {\n    console.log('ok');\n    console.log('still ok');\n}"

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
test "quoting a list produces array" ->
  esl "'(1 2 3)"
    ..`@equals` "[\n    1,\n    2,\n    3\n];"

test "quoting numbers produces numbers" ->
  esl "'(1)"
    ..`@equals` "[1];"

test "quoting strings produces strings" ->
  esl "'(\"hi\")"
    ..`@equals` "['hi'];"

test "quoting atoms produces an object representing it" ->
  esl "'(fun)"
    ..`@equals` "[{ atom: 'fun' }];"

test "macro constructor given object imports properties as macros" ->
  esl '''
      (macro (object a (function () (return '"hi a"))
                     b (function () (return '"hi b"))))
      (a) (b)
      '''
   ..`@equals` "'hi a';\n'hi b';"

test "simple quoting macro" ->
  esl "(macro random (function () (return '((. Math random)))))
       (+ (random) (random))"
    ..`@equals` "Math.random() + Math.random();"

test "simple unquoting macro" ->
  esl "(macro three (function () (return `,(+ 1 2))))
       (three)"
    ..`@equals` "3;"

test "empty-list-returning macro" ->
  esl "(macro nothing (function () (return '())))
       (nothing)"
    ..`@equals` ""

test "empty-list-returning macro (using quasiquote)" ->
  esl "(macro nothing (function () (return `())))
       (nothing)"
    ..`@equals` ""

test "nothing-returning macro" ->
  esl "(macro nothing (function () (return undefined)))
       (nothing)"
    ..`@equals` ""

test "macros mask others defined before with the same name" ->
  esl "(macro m (function () (return ())))
       (macro m (function () (return '((. console log) \"hi\"))))
       (m)"
    ..`@equals` "console.log('hi');"

test "macros can be defined inside function bodies" ->
  esl "(= f (function (x)
         (macro x (function () (return 5)))
         (return (x))))"
    ..`@equals` "var f = function (x) {\n    return 5;\n};"

test "macros go out of scope at the end of the nesting level" ->
  esl "(= f (function (x)
         (macro x (function () (return 5)))
         (return (x))))
       (x)"
    ..`@equals` "var f = function (x) {\n    return 5;\n};\nx();"

test "dead simple quasiquote" ->
  esl "(macro q (function () (return `(+ 2 3))))
       (q)"
    ..`@equals` "2 + 3;"

test "quasiquote is like quote if no unquotes contained" ->
  esl "(macro rand (function ()
                  (return `(* 5
                      ((. Math random))))))
       (rand)"
    ..`@equals` "5 * Math.random();"

test "macros can quasiquote to unquote arguments into output" ->
  esl "(macro rand (function (upper)
                  (return `(* ,upper
                      ((. Math random))))))
       (rand 5)"
    ..`@equals` "5 * Math.random();"

test "macros can unquote modified arguments too" ->
  esl "(macro rand (function (upper)
                  (= x (* 2
                          ((. this evaluate) upper)))
                  (return `(* ,x ((. Math random))))))
       (rand 5)"
    ..`@equals` "10 * Math.random();"


test "macros can evaluate arguments and operate on them further" ->
  esl "(macro increment (function (x)
                  (return (+ 1 ((. this evaluate) x)))))
       (increment 1)"
    ..`@equals` "2;"

test "macros can unquote arrays into quasiquoted lists (non-splicing)" ->
  esl "(macro what (function (x)
                  (return `(,x))))
       (what (+ 2 3))"
    ..`@equals` "(2 + 3)();"

test "macros can splice arrays into quasiquoted lists" ->
  esl "(macro sumOf (function (xs) (return `(+ ,@xs))))
       (sumOf (1 2 3))"
    ..`@equals` "1 + (2 + 3);"

test "macros can splice in empty arrays" ->
  esl "(macro sumOf (function (xs) (return `(+ 1 2 ,@xs))))
       (sumOf ())"
    ..`@equals` "1 + 2;"

test "quasiquote can contain nested lists" ->
  esl '''
      (macro mean
       (function ()
        ; Convert arguments into array
        (= args ((. Array prototype slice call) arguments 0))
        (= total (. args length))
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

test "macro producing an object won't get confused for atom" ->
  esl "(macro obj (function () (return '(object a 1))))
       (obj)"
    ..`@equals` "({ a: 1 });"

test "macro producing a function" ->
  esl "(macro increase (function (n)
                      (return `(function (x) (return (+ x ,n))))))
       (increase 3)"
    ..`@equals` "(function (x) {\n    return x + 3;\n});"

test "macros can operate on their arguments variable" ->
  esl "(macro functionBackwards (function ()
        (= body (. arguments 0))
        (= args ((. Array prototype slice call) arguments 1))
        (return `(function ,@args ,body))))
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
  esl "(macro : (function (body)
       (return `(function (it) ,body))))
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
       ((function () (= x 0)
        (return (object plusPrev  (function (n)
                                  (return (+= x ((. this evaluate) n)) x))
                        timesPrev (function (n)
                                  (return (*= x ((. this evaluate) n)) x)))))))
      (plusPrev 2) (timesPrev 2)
       """
   ..`@equals` "2;\n4;"

test "macro can return multiple statements with `multi`" ->
  esl "(macro declareTwo (function () (return ((. this multi) '(= x 0) '(= y 1)))))
       (declareTwo)"
   ..`@equals` "var x = 0;\nvar y = 1;"

test "macro can ask for atom/string argument type and get text" ->
  esl '''
      (macro stringy (function (x)
       (if (. x atom)
        ((return `,(+ "atom:" (. x atom))))
        ((if (== (typeof x) "string")
         ((return x))
         ((return "An unexpected development!")))))))
      (stringy a)
      (stringy "b")
      '''
    ..`@equals` "'atom:a';\n'b';"

test "macro can generate symbol with unique name" ->
  code = esl '''
    (macro declare (function ()
     (return `(= ,((. this gensym)) null))))
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

test "macro can create atoms by returning an object with key `atom`" ->

  # This is mainly meant for macros written in plain JavaScript or
  # other languages that don't have a quasiquote construct that
  # generates the appropriate code, as eslisp can do.

  # Quasiquoting compiles to this anyway.

  esl '''
      (macro get-content (function (x)
       (= contentAtom (object atom "content"))
       (return `(. ,x ,contentAtom))))
      (get-content a)
      '''
    ..`@equals` "a.content;"

test "macro returning atom with empty or null name fails" ->
  self = this
  <[ "" null undefined ]>.for-each ->
    self.throws do
      -> esl """
          (macro mac (function () (return (object atom #it))))
          (mac)
          """
      Error

test "compiler types are converted to JS ones when passed to macros" ->
  r = esl '''
      (macro check-these (function ()
       (= type
        (function (x)
         (return
          ((. ((. (object) toString call) x) slice)
           8 -1))))

       (return ((. this multi)
                (type (. arguments 0))
                (type (. arguments 1))
                (type (. arguments 2))
                (type (. arguments 3))
                (type (. arguments 4))))))
      (check-these 1 -1 a "a" ())
      '''
  r.split "\n"
    ..length `@equals` 5
    ..0 `@equals` "'Number';"
    ..1 `@equals` "'Number';"
    ..2 `@equals` "'Object';"
    ..3 `@equals` "'String';"
    ..4 `@equals` "'Array';"

test "macros can be required relative to root directory" ->

  # Create dummy temporary file
  file-name = "./#{uuid.v4!}.js"
  fd = fs.open-sync file-name, \a+
  fs.write-sync fd, "module.exports = function() { }"

  esl """
    (macro (object x (require "#file-name")))
    (x)
    """
    ..`@equals` ""

  fs.unlink-sync file-name

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
      return this.multi("ok", this.gensym());
    };
    """

  code = esl """
    (macro (object x (require "#name")))
    (x)
    """

  code.split "\n"
    ..length `@equals` 2
    ..0 `@equals` "'ok';" # first line is the string
    @ok ..1               # second is generated symbol

  fs.unlink-sync name # clean up

test "macro can create implicit last-expr returning function shorthand" ->
  esl '''
    (macro fn (function ()
     (= args ((. Array prototype slice call) arguments))
     (= fnArgs (. args  0))
     (= fnBody ((. args slice) 1))

     (= last ((. fnBody pop)))

     (= lastConverted
      (?: ((. this isExpr) last)
          `(return ,last)
          last))

     ((. fnBody push) lastConverted)

     (return `(function ,fnArgs ,@fnBody))))

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

test "macro function can be returned from IIFE" ->
  # IIFE = immediately-invoked function expression
  #
  # Note how the outer function is wrapped in another set of parens to
  # immediately call it.  It returns another function, and *that* becomes the
  # macro.
  esl '''
    (macro say-hi ((function ()
      (return (function () (return "hi"))))))
    (say-hi)
    '''
    ..`@equals` "'hi';"

test "IIFE given to macro can itself contain other macros" ->
  esl '''
    (macro say-hi ((function ()
      (macro x (function() (return '"hi")))
      (return (function () (return (x)))))))
    (say-hi)
    '''
    ..`@equals` "'hi';"

test "macro-generating macro" -> # yes srsly
  esl '''
    (macro define-with-name (function (x)
      (return `(macro ,x (function () (return `(= hello 5)))))))
    (define-with-name what)
    (what)
    '''
    ..`@equals` "var hello = 5;"

test "macro generating macro and macro call" -> # yes srsly squared
  esl '''
    (macro define-and-call (function (x)
      (return ((. this multi) `(macro what (function () (return `(hello))))
                              `(what)))))
    (define-and-call)
    '''
    ..`@equals` "hello();"

test "macros do not capture macros from the outer env by default" ->
  # A macro's environment is ordinarily the clean root macro table; it ignores
  # user-defined macros.
  esl '''
    (macro f (function () (return '"hello")))
    (macro g (function () (return '(f))))
    (g)
    '''
    ..`@equals` "f();"

test "capmacro allows macros capture from outer env" ->
  # To create a macro that *does* capture the current macro environment, use
  # `capmacro`.
  esl '''
    (capmacro f (function () (return '"hello")))
    (capmacro g (function () (return '(f))))
    (g)
    '''
    ..`@equals` "'hello';"

test "capturing macros are referentially transparent" ->
  # A macro that captures its environment does so when defined, not when
  # called.  This means it's robust to later redefinitions in the same scope it
  # captured from.
  esl '''
    (macro say (function () (return '(yes))))    ; define macro "say"
    (capmacro m   (function () (return '(say)))) ; use "say" in "m"
    (macro say (function () (return '(no))))     ; redefine macro "say"
    (m)                                          ; call macro "m"
    '''
    ..`@equals` "yes();"

test "invalid AST returned by macro throws error" ->
  @throws do
    ->
      # `console.log` is invalid as a variable name, but if used as if it were
      # one, without checking if the AST makes sense, this will compile to
      # valid JavaScript code of `console.log('hi');`!
      esl '''
        (macro hack (function () (return '(console.log "hi"))))
        (hack)
        '''
    Error

test "macro return intermediates may be invalid if fixed by later macro" ->
  # `...` is an invalid variable name, but since it's corrected by a later
  # macro before evaluation, that's fine.
  esl '''
    (macro callDots (function () (return '(...))))
    (macro replaceDots (function () (return 'x)))
    (replaceDots (callDots))
    '''
      ..`@equals` "x;"

test "multiple invocations of the compiler are separate" ->
  esl "(macro what (function () (return 'hi)))"
  esl "(what)"
    .. `@equals` "what();" # instead of "hi;"
