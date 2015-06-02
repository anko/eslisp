# eslisp [![](https://img.shields.io/badge/api-unstable-red.svg?style=flat-square)][1] [![](https://img.shields.io/travis/anko/eslisp.svg?style=flat-square)][2] [![](https://img.shields.io/badge/chat-gitter_%E2%86%92-blue.svg?style=flat-square)][3]

[S-expression][4] syntax for [ECMAScript][5]/JavaScript, with [lisp macros][6].
Unopinionated and extensible.  Minimum [magic][7] or [sugar][8].

<!-- !test program ./bin/eslc | head -c -1 -->

<!-- !test in fib -->

    ; Only include given statement if `$DEBUG` environment variable is set
    (macro debug (statement)
     (return (?: (. process env DEBUG)
                 statement
                 null)))

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
part of the compiled code.  User-defined macros are treated equivalently to
predefined ones.  They can [`quasiquote`][22] (`` ` ``) and `unquote` (`,`)
values into their outputs, or `evaluate` their arguments to perform arbitrary
computations on them first.

<!-- !test in macro and call -->

    (macro m (x) (return `(+ ,x 2)))
    ((. console log) (m 40))

    (macro m2 (x) (return `,(+ (evaluate x) 2)))
    ((. console log) (m2 40))

<!-- !test out macro and call -->

    console.log(40 + 2);
    console.log(42);

You can even return multiple statements from a macro (with the `multi`
function, which is only defined inside macros).

<!-- !test in multiple-return macro -->

    (macro what (varName)
     (return (multi `((. console log) ((. JSON stringify) ,varName))
                  `(++ ,varName))))
    (what ever)

<!-- !test out multiple-return macro -->

    console.log(JSON.stringify(ever));
    ++ever;

Returning `null` from a macro just means nothing.  This is handy for
compilation side-effects or conditional compilation.

<!-- !test in nothing-returning macro -->

    ; Only include statement if `$DEBUG` environment variable is set
    (macro debug (statement)
     (return (?: (. process env DEBUG) statement null)))

    (debug ((. console log) "debug output"))
    (yep)

<!-- !test out nothing-returning macro -->

    yep();

If you want macros that can share state between each other, create a `macros`
block and return an object.  Each key-value pair of the object is interned as a
macro.

<!-- !test in macros block -->

    (macros (= x 0)
            (return (object increment (function () (return (++ x)))
                            decrement (function () (return (-- x)))
                            get       (function () (return x)))))

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

Want more?  [The tests][23] are basically a language tutorial.

## Try it

Clone this repo and `npm install` to get the compiler in `bin/eslc`.  Pipe
eslisp to it. Receive ECMAScript.

    echo '((. console log) "Yo!")' | ./bin/eslc

If you want `eslc` in your [`$PATH`][24], `npm install --global`.

To remove it cleanly, `npm uninstall --global`.

## How does it work

A table of predefined macros is used to turn S-expressions into [SpiderMonkey
AST][25], which is fed to [escodegen][26], which outputs JS.  Some of those
macros allow defining further macros, which get added to the table and
henceforth work just like the predefined ones do.

## Comparison to other JS-lisps

Here's an overview of other compile-to-JS lisps and how they compare to eslisp.
I'll go in rough order of decreasing similarity.

### Independent JS lisp implementations

[**Jisp**][27] is the most similar existing project. It has implemented macros
slightly differently in the details, and is more opinionated about how code
should be written; everything is an expression, sometimes at the cost of a
one-to-one language mapping.  It is currently not actively maintained.

[**Sibilant**][28] also emphasises staying close to JavaScript semantics, but
unlike eslisp, it accepts extensive syntactic sugar and its macros (though
featureful) are cumbersome to write.

[**LispyScript**][29] adds syntactic sugar quite aggressively.  Its "macros"
are really just subsitution templates: they can't do computation, which allows
only extremely simple uses.

### Subsets of other lisps in JS

[**wisp**][30] is a [Clojure][31] subset, inheriting its syntax and many ideas,
but is friendlier to JavaScript.  It is more mature and featureful than eslisp.
However, its syntax inherits some Clojure-isms that translate awkwardly to JS
and its macros compile to an internal representation, so they can't be defined
in separate modules.

[**Ralph**][32] is a [Dylan][33] subset.  It compiles to JavaScript and has a
quasiquoting macro system, but it again has lots some syntax that doesn't
translate obviously into JS.  Allows macros to be defined in separate modules.
Currently not actively maintained.

### Compilers hosted on other lisps

[**ClojureScript**][34] is a heavy approach; a full [Clojure][35] compiler
targeting JavaScript.  Unlike eslisp, it requires the [JVM][36] and totally
overrides JS' semantics.

[**Parenscript**][37] similarly requires a Common Lisp compiler.  It uses CL
idioms, but is implemented instead as a CL library, allowing it to make a
little more effort than ClojureScript to produce readable JavaScript output.

### Lisp interpreters in JS

[**SLip**][38], [**Javathcript**][39], [**Fargo**][40] (and many others) are
interpreters; they work on internal code representations and so have limited
interoperability with other JavaScript.

## License

[ISC][41].

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
[23]: https://github.com/anko/eslisp/blob/master/test.ls
[24]: http://en.wikipedia.org/wiki/PATH_(variable)
[25]: https://developer.mozilla.org/en-US/docs/Mozilla/Projects/SpiderMonkey/Parser_API
[26]: https://github.com/estools/escodegen
[27]: http://jisp.io/
[28]: http://sibilantjs.info/
[29]: http://lispyscript.com/
[30]: https://github.com/Gozala/wisp
[31]: http://clojure.org/
[32]: https://github.com/turbolent/ralph
[33]: http://en.wikipedia.org/wiki/Dylan_(programming_language)
[34]: https://github.com/clojure/clojurescript
[35]: http://clojure.org/
[36]: http://en.wikipedia.org/wiki/Java_virtual_machine
[37]: https://common-lisp.net/project/parenscript/
[38]: http://lisperator.net/slip/
[39]: http://kybernetikos.github.io/Javathcript/
[40]: https://github.com/jcoglan/fargo
[41]: http://opensource.org/licenses/ISC
