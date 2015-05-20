# eslisp [![](https://img.shields.io/badge/api-unstable-red.svg?style=flat-square)][1]

An [s-expression][2] syntax for [ECMAScript][3], with actually good
[macros][4].  Minimum [magic][5] or [sugar][6].

Why:

-   **Syntax should be changeable**.  S-expressions are a minimal homoiconic
    representation of an [Abstract Syntax Tree][7] and [lisp macros rock][8]
    for good reason.  Let's use what works.

-   **Syntactic features should be modular**.  For example, getting an
    [anaphoric conditional][9] should be a matter of `npm install esl-aif`.

-   **[Hack value][10]**.  Code that writes code is the coolest thing since
    mint ice cream.  [Conditional compilation][11]!  [DLSs][12]!
    [Anaphora][13]!  [*So cool*][14].

-   **Existing [JavaScript lisps][15] are lacking in parts**.  Few have proper
    quasiquoting, which makes them feel pointless.  Those that do emulate
    existing lisps strongly, resulting in needlessly complex syntax,
    [featuritis][16] and stuff that feels foreign to JavaScript programmers.

## Examples

<!-- !test program ./bin/eslc | head -c -1 -->

Nested parentheses represent macro- or function-calls.  Here `.` is a
compiler-defined macro representing property access, so `(. console log)`
becomes `console.log`, and

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

Loops are as you'd expect.

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
predefined ones.  They can [`quasiquote`][17] (`` ` ``) and `unquote` (`,`)
values into their outputs, or `evaluate` their arguments to perform arbitrary
computations on them first.

<!-- !test in macro and call -->

    (macro m (x) `(+ ,x 2))
    ((. console log) (m 40))

    (macro m2 (x) `,(+ (evaluate x) 2))
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

## Try it

Clone this repo and `npm install` to get the compiler in `bin/eslc`.

Pipe eslisp to it. Receive ECMAScript.

    echo '((. console log) "Yo!")' | ./bin/eslc

If you want `eslc` in your [`$PATH`][18], `npm install --global`.  To remove it
cleanly, `npm uninstall --global`.

## How does it work

It has a table of predefined macros to turn S-expressions into [SpiderMonkey
AST][19] and feeds that to [escodegen][20].  Some of those macros allow
defining more macros.  Apart from some little details, that's pretty much it.

## License

[ISC][21].

[1]: http://semver.org/
[2]: https://en.wikipedia.org/wiki/S-expression
[3]: http://en.wikipedia.org/wiki/ECMAScript
[4]: http://stackoverflow.com/questions/267862/what-makes-lisp-macros-so-special
[5]: http://www.catb.org/jargon/html/M/magic.html
[6]: http://en.wikipedia.org/wiki/Syntactic_sugar
[7]: http://en.wikipedia.org/wiki/Abstract_syntax_tree
[8]: http://blog.rongarret.info/2015/05/why-lisp.html
[9]: https://en.wikipedia.org/wiki/Anaphoric_macro
[10]: http://www.catb.org/jargon/html/H/hack-value.html
[11]: http://en.wikipedia.org/wiki/Conditional_compilation
[12]: http://en.wikipedia.org/wiki/Domain-specific_language
[13]: http://en.wikipedia.org/wiki/Anaphoric_macro
[14]: http://c2.com/cgi/wiki?LispMacro
[15]: http://ceaude.twoticketsplease.de/js-lisps.html
[16]: http://en.wikipedia.org/wiki/Feature_creep
[17]: http://axisofeval.blogspot.co.uk/2013/04/a-quasiquote-i-can-understand.html
[18]: http://en.wikipedia.org/wiki/PATH_(variable)
[19]: https://developer.mozilla.org/en-US/docs/Mozilla/Projects/SpiderMonkey/Parser_API
[20]: https://github.com/estools/escodegen
[21]: http://opensource.org/licenses/ISC
