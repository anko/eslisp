# eslisp [![](https://img.shields.io/badge/api-unstable-red.svg?style=flat-square)][1] [![](https://img.shields.io/travis/anko/eslisp.svg?style=flat-square)][2] [![](https://img.shields.io/badge/chat-gitter_%E2%86%92-blue.svg?style=flat-square)][3]

[S-expression][4] syntax for [ECMAScript][5]/JavaScript, with [lisp-like
macros][6].  Unopinionated and extensible.  Minimum [magic][7] or [sugar][8].

<!-- !test program ./bin/eslc | head -c -1 -->

<!-- !test in fib -->

    ; Only include given statement if `$DEBUG` environment variable is set
    (macro debug (function (statement)
     (return (?: (. process env DEBUG)
                 statement
                 null))))

    (= fib ; Fibonacci number sequence
       (function (x)
        (debug ((. console log) (+ "resolving number " x)))
        (switch x
         (0 (return 0))
         (1 (return 1))
         (default (return (+ (fib (- x 1)) (fib (- x 2))))))))

<!-- !test out fib -->

    var fib = function (x) {
        switch (x) {
        case 0:
            return 0;
        case 1:
            return 1;
        default:
            return fib(x - 1) + fib(x - 2);
        }
    };

## Philosophy

-   **Close to JS**.  Eslisp input will match clearly with output JS.
    [Lisp][9] is the inspiration, not the goal.  Fancy features will be
    enabled, but delivered by other modules.

-   **Embrace macros**.  Code should be changeable by other programs.
    S-expressions are a minimal [homoiconic][10] representation of a language's
    [abstract syntax tree][11], and [they rock][12], so let's use what works.

-   **Packaging-friendly**.  You should be able to easily choose what syntax is
    right for you and to publish your macros.  (For example, using an
    [anaphoric conditional][13] from [npm][14] should be a matter of `npm
    install esl-aif` and `require`-ing that in a macro.)

Also, this had great [hack value][15].  [Metaprogramming][16] is the coolest
thing since mint ice cream.  [Conditional compilation][17]!  [DSLs][18]!
[Anaphora][19]!  [*So cool*][20].

Versioning will follow [semver][21].

## Examples

Nested parentheses represent macro- or function-calls.  Here `.` is a
compiler-defined macro representing property access, so `(. console log)`
becomes `console.log`, and

<!-- !test in initial -->

    ((. console log) "Hello world!")

becomes

<!-- !test out initial -->

    console.log('Hello world!');

* * *

The function-constructing macro takes a list of arguments first.  The rest are
treated like the statements in the function body.

<!-- !test in func and call -->

    (= f (function (x) (return (+ x 2))))
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
part of the compiled code.  User-defined macros and pre-defined compiler ones
are treated equivalently.  They can [`quasiquote`][22] (`` ` ``) and `unquote`
(`,`) values into their outputs and perform arbitrary computations.  They can
also use the methods defined in `this` to examine (`isExpr`, `isAtom`,
`isString`) and `evaluate` their arguments.

<!-- !test in macro and call -->

    (macro m (function (x) (return `(+ ,x 2))))
    ((. console log) (m 40))

    (macro m2 (function (x) (return `,(+ ((. this evaluate) x) 2))))
    ((. console log) (m2 40))

<!-- !test out macro and call -->

    console.log(40 + 2);
    console.log(42);

You can even return multiple statements from a macro (with the `multi`
function, which is only defined inside macros).

<!-- !test in multiple-return macro -->

    (macro what (function (varName)
     (return ((. this multi)
              `((. console log) ((. JSON stringify) ,varName))
              `(++ ,varName)))))
    (what ever)

<!-- !test out multiple-return macro -->

    console.log(JSON.stringify(ever));
    ++ever;

Returning `null` from a macro just means nothing.  This is handy for
compilation side-effects or conditional compilation.

<!-- !test in nothing-returning macro -->

    ; Only include statement if `$DEBUG` environment variable is set
    (macro debug (function (statement)
     (return (?: (. process env DEBUG) statement null))))

    (debug ((. console log) "debug output"))
    (yep)

<!-- !test out nothing-returning macro -->

    yep();

If you want macros that can share state between each other, just pass an
[immediately-invoked function expression (IIFE)][23] to `macro` and return an
object.  Each property of the object is interned as a macro.  The variables in
the IIFE closure are shared between them.

<!-- !test in macros block -->

    (macro ((function ()
            (= x 0)
            (return (object increment (function () (return (++ x)))
                            decrement (function () (return (-- x)))
                            get       (function () (return x)))))))

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

Want more?  [The tests][24] are basically a language tutorial.

## Try it

Clone this repo and `npm install` to get the compiler in `bin/eslc`.  Pipe
eslisp to it. Receive ECMAScript.

    echo '((. console log) "Yo!")' | ./bin/eslc

If you want `eslc` in your [`$PATH`][25], `npm install --global`.

To remove it cleanly, `npm uninstall --global`.

## How does it work

A table of predefined macros is used to turn S-expressions into [SpiderMonkey
AST][26], which is fed to [escodegen][27], which outputs JS.  Some of those
macros allow defining further macros, which get added to the table and
henceforth work just like the predefined ones do.

The [brief comparison to other JS lisp-likes][28] might be interesting too.

## License

[ISC][29].

[1]: http://semver.org/
[2]: https://travis-ci.org/anko/eslisp
[3]: https://gitter.im/anko/eslisp
[4]: https://en.wikipedia.org/wiki/S-expression
[5]: http://en.wikipedia.org/wiki/ECMAScript
[6]: http://stackoverflow.com/questions/267862/what-makes-lisp-macros-so-special
[7]: http://www.catb.org/jargon/html/M/magic.html
[8]: http://en.wikipedia.org/wiki/Syntactic_sugar
[9]: https://en.wikipedia.org/wiki/Lisp_(programming_language)
[10]: http://en.wikipedia.org/wiki/Homoiconicity
[11]: http://en.wikipedia.org/wiki/Abstract_syntax_tree
[12]: http://blog.rongarret.info/2015/05/why-lisp.html
[13]: https://en.wikipedia.org/wiki/Anaphoric_macro
[14]: https://www.npmjs.com/
[15]: http://www.catb.org/jargon/html/H/hack-value.html
[16]: http://en.wikipedia.org/wiki/Metaprogramming
[17]: http://en.wikipedia.org/wiki/Conditional_compilation
[18]: http://en.wikipedia.org/wiki/Domain-specific_language
[19]: http://en.wikipedia.org/wiki/Anaphoric_macro
[20]: http://c2.com/cgi/wiki?LispMacro
[21]: http://semver.org/spec/v2.0.0.html
[22]: http://axisofeval.blogspot.co.uk/2013/04/a-quasiquote-i-can-understand.html
[23]: https://en.wikipedia.org/wiki/Immediately-invoked_function_expression
[24]: https://github.com/anko/eslisp/blob/master/test.ls
[25]: http://en.wikipedia.org/wiki/PATH_(variable)
[26]: https://developer.mozilla.org/en-US/docs/Mozilla/Projects/SpiderMonkey/Parser_API
[27]: https://github.com/estools/escodegen
[28]: doc/comparison-to-other-js-lisps.markdown
[29]: http://opensource.org/licenses/ISC
