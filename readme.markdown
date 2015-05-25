# eslisp [![](https://img.shields.io/badge/api-unstable-red.svg?style=flat-square)][1]

[S-expression][2] syntax for [ECMAScript][3], with [lisp macros][4].
Unopinionated, with minimum [magic][5] or [sugar][6].  Intended as an
extensible base for further syntax abstractions.

*I'll use the terms ECMAScript, JavaScript and JS interchangeably here, because
[the difference][7] is fairly unimportant.*

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
         (0 (return 1))
         (1 (return 1))
         (default (return (+ (fib x) (fib (- x 1))))))))

<!-- !test out fib -->

    var fib = function (x) {
        switch (x) {
        case 0:
            return 1;
        case 1:
            return 1;
        default:
            return fib(x) + fib(x - 1);
        }
    };

## Philosophy

-   **Plain JS, in S-expressions**.  The language core should (as much as
    reasonable) match the output JS one-to-one.  Lisp is an inspiration here,
    not the only goal.

-   **Embrace macros**.  S-expressions are a minimal homoiconic representation
    of a language's [Abstract Syntax Tree][8], which makes it a breeze to
    modify the fundamental syntax of the language.  [Lisp macros rock][9], and
    for good reason.  Let's use what works.

-   **Optional, modular syntactic features**.  For example, using an [anaphoric
    conditional][10] from [npm][11] should be a matter of `npm install esl-aif`
    and `require`-ing that.  Choose the syntax that works for you.

Also, this had too much [hack value][12] to pass up.  Code that writes code is
the coolest thing since mint ice cream.  [Conditional compilation][13]!
[DLSs][14]!  [Anaphora][15]!  [*So cool*][16].

[Semantic versioning ^2.0.0][17] will be followed.

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
predefined ones.  They can [`quasiquote`][18] (`` ` ``) and `unquote` (`,`)
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

Want more?  [The tests][19] are basically a language tutorial.

## Try it

Clone this repo and `npm install` to get the compiler in `bin/eslc`.  Pipe
eslisp to it. Receive ECMAScript.

    echo '((. console log) "Yo!")' | ./bin/eslc

If you want `eslc` in your [`$PATH`][20], `npm install --global`.

To remove it cleanly, `npm uninstall --global`.

## How does it work

A table of predefined macros is used to turn S-expressions into [SpiderMonkey
AST][21], which is fed to [escodegen][22], which outputs JS.  Some of those
macros allow defining further macros, which get added to the table and
henceforth work just like the predefined ones do.

## Comparison to other JS-lisps

Here's an overview of other compile-to-JS lisps and how they compare to eslisp.
I'll go in rough order of decreasing similarity.

### Independent JS lisp implementations

[**Jisp**][23] is the most similar existing project. It has implemented macros
slightly differently in the details, and is more opinionated about how code
should be written; everything is an expression, sometimes at the cost of a
one-to-one language mapping.  It is currently not actively maintained.

[**Sibilant**][24] also emphasises staying close to JavaScript semantics, but
unlike eslisp, it accepts extensive syntactic sugar and its macros (though
featureful) are cumbersome to write.

[**LispyScript**][25] adds syntactic sugar quite aggressively.  Its "macros"
are really just subsitution templates: they can't do computation, which allows
only extremely simple uses.

### Subsets of other lisps in JS

[**wisp**][26] is a [Clojure][27] subset, inheriting its syntax and many ideas,
but is friendlier to JavaScript.  It is more mature and featureful than eslisp.
However, its syntax inherits some Clojure-isms that translate awkwardly to JS
and its macros compile to an internal representation, so they can't be defined
in separate modules.

[**Ralph**][28] is a [Dylan][29] subset.  It compiles to JavaScript and has a
quasiquoting macro system, but it again has lots some syntax that doesn't
translate obviously into JS.  Allows macros to be defined in separate modules.
Currently not actively maintained.

### Compilers hosted on other lisps

[**ClojureScript**][30] is a heavy approach; a full [Clojure][31] compiler
targeting JavaScript.  Unlike eslisp, it requires the [JVM][32] and totally
overrides JS' semantics.

[**Parenscript**][33] similarly requires a Common Lisp compiler.  It uses CL
idioms, but is implemented instead as a CL library, allowing it to make a
little more effort than ClojureScript to produce readable JavaScript output.

### Lisp interpreters in JS

[**SLip**][34], [**Javathcript**][35], [**Fargo**][36] (and many others) are
interpreters; they work on internal code representations and so have limited
interoperability with other JavaScript.

## License

[ISC][37].

[1]: http://semver.org/
[2]: https://en.wikipedia.org/wiki/S-expression
[3]: http://en.wikipedia.org/wiki/ECMAScript
[4]: http://stackoverflow.com/questions/267862/what-makes-lisp-macros-so-special
[5]: http://www.catb.org/jargon/html/M/magic.html
[6]: http://en.wikipedia.org/wiki/Syntactic_sugar
[7]: http://stackoverflow.com/questions/912479/what-is-the-difference-between-javascript-and-ecmascript
[8]: http://en.wikipedia.org/wiki/Abstract_syntax_tree
[9]: http://blog.rongarret.info/2015/05/why-lisp.html
[10]: https://en.wikipedia.org/wiki/Anaphoric_macro
[11]: https://www.npmjs.com/
[12]: http://www.catb.org/jargon/html/H/hack-value.html
[13]: http://en.wikipedia.org/wiki/Conditional_compilation
[14]: http://en.wikipedia.org/wiki/Domain-specific_language
[15]: http://en.wikipedia.org/wiki/Anaphoric_macro
[16]: http://c2.com/cgi/wiki?LispMacro
[17]: http://semver.org/
[18]: http://axisofeval.blogspot.co.uk/2013/04/a-quasiquote-i-can-understand.html
[19]: https://github.com/anko/eslisp/blob/master/test.ls
[20]: http://en.wikipedia.org/wiki/PATH_(variable)
[21]: https://developer.mozilla.org/en-US/docs/Mozilla/Projects/SpiderMonkey/Parser_API
[22]: https://github.com/estools/escodegen
[23]: http://jisp.io/
[24]: http://sibilantjs.info/
[25]: http://lispyscript.com/
[26]: https://github.com/Gozala/wisp
[27]: http://clojure.org/
[28]: https://github.com/turbolent/ralph
[29]: http://en.wikipedia.org/wiki/Dylan_(programming_language)
[30]: https://github.com/clojure/clojurescript
[31]: http://clojure.org/
[32]: http://en.wikipedia.org/wiki/Java_virtual_machine
[33]: https://common-lisp.net/project/parenscript/
[34]: http://lisperator.net/slip/
[35]: http://kybernetikos.github.io/Javathcript/
[36]: https://github.com/jcoglan/fargo
[37]: http://opensource.org/licenses/ISC
