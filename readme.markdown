# eslisp [![](https://img.shields.io/badge/api-unstable-red.svg?style=flat-square)][1]

An [s-expression][2] syntax for [ECMAScript][3], with [macros][4].
Deliberately small and close to plain ES, with little [sugar][5].  Intended as
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

Macros are functions that run at compile-time.  User-defined macros are treated
equivalently to predefined ones.  They can [`quasiquote`][9] (`` ` ``) and
`unquote` (`,`) values into their outputs, or `evaluate` their arguments to
perform arbitrary computations.

<!-- !test in macro and call -->

    (macro m (x) `(+ ,x 2))
    ((. console log) (m 40))

    (macro m2 (x) (+ (evaluate x) 2))
    ((. console log) (m2 40))

<!-- !test out macro and call -->

    console.log(40 + 2);
    console.log(42);

* * *

See the unit tests for more.

## Why

-   **To learn how lisp works**; a [Rite of the Rewrite][10], sans low-level
    tedium.  (The code generation stack just feeds [escodegen][11] with
    [SpiderMonkey AST][12].)

-   **To improve on [JavaScript lisp implementations][13]' macro systems**.
    Few have proper quasiquoting macro systems, which makes them feel
    pointless.  Those that do are reimplementations of existing lisps (e.g.
    Clojure), resulting in needlessly complex language-semantic mappings.  It
    should be "just JavaScript" (as [CoffeeScript][14] likes to say), but with
    S-expressions and macros.

-   **Because macros**.  Code that writes code is the coolest thing since mint
    ice cream.  [Conditional compilation][15]!  [DLSs][16]!  [Anaphora][17]!
    [*So cool*][18].

## Try it

Clone this repo and `npm install` to get the compiler in `bin/eslc`.

Pipe stuff to it.  Receive JS:

    echo '((. console log) "Yo!")' | ./bin/eslc

If you want `eslc` in your [`$PATH`][8], install with `npm install --global`.
To remove it cleanly, `npm uninstall --global`.

## License

[ISC][19].

[1]: http://semver.org/
[2]: https://en.wikipedia.org/wiki/S-expression
[3]: http://en.wikipedia.org/wiki/ECMAScript
[4]: http://stackoverflow.com/questions/267862/what-makes-lisp-macros-so-special
[5]: http://en.wikipedia.org/wiki/Syntactic_sugar
[6]: https://www.npmjs.com/
[7]: http://semver.org/
[8]: http://en.wikipedia.org/wiki/PATH_(variable)
[9]: http://axisofeval.blogspot.co.uk/2013/04/a-quasiquote-i-can-understand.html
[10]: http://web.mit.edu/daveg/Info/loginataka
[11]: https://github.com/estools/escodegen
[12]: https://developer.mozilla.org/en-US/docs/Mozilla/Projects/SpiderMonkey/Parser_API
[13]: http://ceaude.twoticketsplease.de/js-lisps.html
[14]: http://coffeescript.org/
[15]: http://en.wikipedia.org/wiki/Conditional_compilation
[16]: http://en.wikipedia.org/wiki/Domain-specific_language
[17]: http://en.wikipedia.org/wiki/Anaphoric_macro
[18]: http://c2.com/cgi/wiki?LispMacro
[19]: http://opensource.org/licenses/ISC
