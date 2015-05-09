# eslisp [![](https://img.shields.io/badge/api-unstable-red.svg?style=flat-square)][1]

An [s-expression][2] syntax for [ECMAScript][3], with [macros][4], because
[lisp is pretty amazing][5].

Deliberately small and close to plain ES, with little [sugar][6].  Intended as
a tool for writing JavaScript which is extensible with macros.  This is an
experiment, but would be neat if it became an Actual Thing.

**Still in development**.  No API stability guarantees until v1.0.0, following
[semver][7].  Still missing comment support, a good mechanism for defining
macros separately from using them, quasiquote nesting, some JS language
features, and a good tutorial.

## Examples

<!-- !test program ./bin/eslc | head -c -1 -->

As you'd expect from lisp, nested parentheses represent macro- or
function-calls.  Here `.` is a compiler-defined macro representing property
access, so `(. console log)` becomes `console.log`, and

<!-- !test in initial -->

    ((. console log) "Hello world!")

becomes

<!-- !test out initial -->

    console.log('Hello world!');

* * *

The function-constructing macro is called `lambda` and implicitly returns the
last thing in its body if it's an expression.  (Both of these things will
probably change.)

<!-- !test in func and call -->

    (= f (lambda (x) (+ x 2)))
    (f 40)

<!-- !test out func and call -->

    var f = function (x) {
        return x + 2;
    };
    f(40);

* * *

Loops are what you'd expect.

<!-- !test in while loop -->

    (= n 10)
    (while (-- n) ((. console log) n))

<!-- !test out while loop -->

    var n = 10;
    while (--n) {
        console.log(n);
    }

* * *

Macros are functions that run at compile-time.  Whatever they return becomes
part of the compiled code.  User-defined macros are treated equivalently to
predefined ones.  They can [`quasiquote`][8] (`` ` ``) and `unquote` (`,`)
values into their outputs, or `evaluate` their arguments to perform arbitrary
computations on them first.

<!-- !test in macro and call -->

    (macro m (x) `(+ ,x 2))
    ((. console log) (m 40))

    (macro m2 (x) (+ (evaluate x) 2))
    ((. console log) (m2 40))

<!-- !test out macro and call -->

    console.log(40 + 2);
    console.log(42);

If you want macros that can share state between each other, create a `macros`
block and return an object.  Each key-value pair of the object is interned as a
macro.

<!-- !test in macros block -->

    (macros (= x 0)
            (object increment (lambda () (++ x))
                    decrement (lambda () (-- x))
                    get       (lambda () x)))

    (increment)
    (increment)
    (increment)

    (decrement)

<!-- !test out macros block -->

    1;
    2;
    3;
    2;

* * *

See the unit tests for more.

## Why

-   **To learn how lisp works**; a [Rite of the Rewrite][9], sans low-level
    tedium.  (The code generation stack just feeds [escodegen][10] with
    [SpiderMonkey AST][11].)

-   **To improve on [JavaScript lisp implementations][12]' macro systems**.
    Few have proper quasiquoting macro systems, which makes them feel
    pointless.  Those that do are reimplementations of existing lisps (e.g.
    Clojure), resulting in needlessly complex language-semantic mappings.  It
    should be "just JavaScript" (as [CoffeeScript][13] likes to say), but with
    S-expressions and macros.

-   **Because macros**.  Code that writes code is the coolest thing since mint
    ice cream.  [Conditional compilation][14]!  [DLSs][15]!  [Anaphora][16]!
    [*So cool*][17].

## Try it

Clone this repo and `npm install` to get the compiler in `bin/eslc`.

Pipe eslisp to it. Receive ECMAScript.

    echo '((. console log) "Yo!")' | ./bin/eslc

If you want `eslc` in your [`$PATH`][18], install with `npm install --global`.
To remove it cleanly, `npm uninstall --global`.

## License

[ISC][19].

[1]: http://semver.org/
[2]: https://en.wikipedia.org/wiki/S-expression
[3]: http://en.wikipedia.org/wiki/ECMAScript
[4]: http://stackoverflow.com/questions/267862/what-makes-lisp-macros-so-special
[5]: http://blog.rongarret.info/2015/05/why-lisp.html
[6]: http://en.wikipedia.org/wiki/Syntactic_sugar
[7]: http://semver.org/
[8]: http://axisofeval.blogspot.co.uk/2013/04/a-quasiquote-i-can-understand.html
[9]: http://web.mit.edu/daveg/Info/loginataka
[10]: https://github.com/estools/escodegen
[11]: https://developer.mozilla.org/en-US/docs/Mozilla/Projects/SpiderMonkey/Parser_API
[12]: http://ceaude.twoticketsplease.de/js-lisps.html
[13]: http://coffeescript.org/
[14]: http://en.wikipedia.org/wiki/Conditional_compilation
[15]: http://en.wikipedia.org/wiki/Domain-specific_language
[16]: http://en.wikipedia.org/wiki/Anaphoric_macro
[17]: http://c2.com/cgi/wiki?LispMacro
[18]: http://en.wikipedia.org/wiki/PATH_(variable)
[19]: http://opensource.org/licenses/ISC
