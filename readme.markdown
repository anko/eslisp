# eslisp [![](https://img.shields.io/badge/api-unstable-red.svg?style=flat-square)][1]

Unopinionated "small core" [s-expression][2] syntax for [ECMAScript][3], with
[macros][4].  Minimum [magic][5] or [sugar][6].  Extension-friendly.

Philosophy:

-   **Just plain JS, just with macros and macro-friendly syntax**.  The
    language core should as far as reasonable match the output JS one-to-one.
    Syntactic sugar should be optional and provided by macros that are
    separately maintained.

-   **Macros front and center**.  S-expressions are a minimal homoiconic
    representation of an [Abstract Syntax Tree][7] and [lisp macros rock][8]
    for good reason.  Let's use what works.

-   **Syntactic features should be on [npm][9]**.  For example, getting an
    [anaphoric conditional][10] should be a matter of `npm install esl-aif` and
    `require`-ing that.  Further languages can be built on that.

-   **Trivially machine-changeable code is a virtue**.  Programmatic generation
    of code is a huge time-saver and it should be trivial where possible, so
    anyone can metaprogram.

Also, this had too much [hack value][11] to pass up.  Code that writes code is
the coolest thing since mint ice cream.  [Conditional compilation][12]!
[DLSs][13]!  [Anaphora][14]!  [*So cool*][15].

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

The function-constructing macro is called `lambda`.

<!-- !test in func and call -->

    (= f (lambda (x) (return (+ x 2))))
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
predefined ones.  They can [`quasiquote`][16] (`` ` ``) and `unquote` (`,`)
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

    (macro debug (statement)
     ; Only return statement if `DEBUG` environment variable is set
     (?: (. process env DEBUG) statement null))

    (debug ((. console log) "debug output"))
    (yep)

<!-- !test out nothing-returning macro -->

    yep();

If you want macros that can share state between each other, create a `macros`
block and return an object.  Each key-value pair of the object is interned as a
macro.

<!-- !test in macros block -->

    (macros (= x 0)
            (return (object increment (lambda () (return (++ x)))
                            decrement (lambda () (return (-- x)))
                            get       (lambda () (return x)))))

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

If you want `eslc` in your [`$PATH`][17], `npm install --global`.  To remove it
cleanly, `npm uninstall --global`.

## How does it work

It has a table of predefined macros to turn S-expressions into [SpiderMonkey
AST][18] and feeds that to [escodegen][19].  Some of those macros allow
defining further macros.  Apart from some little details, that's pretty much
it.

## Comparison to other JS-lisps

Here's an overview of other compile-to-JS lisps and how they compare to eslisp.
I'll go in rough order of decreasing similarity.

### Independent JS lisp implementations

[**Jisp**][20] is the most similar existing project. It has implemented macros
slightly differently in the details, and is more opinionated about how code
should be written; everything is an expression, sometimes at the cost of a
one-to-one language mapping.  It is currently not actively maintained.

[**Sibilant**][21] also emphasises staying close to JavaScript semantics, but
unlike eslisp, it accepts extensive syntactic sugar and its macros (though
featureful) are cumbersome to write.

[**LispyScript**][22] adds syntactic sugar quite aggressively.  Its "macros"
are really just subsitution templates: they can't do computation, which allows
only extremely simple uses.

### Subsets of other lisps in JS

[**wisp**][23] is a [Clojure][24] subset, inheriting its syntax and many ideas,
but is friendlier to JavaScript.  It is more mature and featureful than eslisp.
However, its syntax inherits some Clojure-isms that translate awkwardly to JS
and its macros compile to an internal representation, so they can't be defined
in separate modules.

[**Ralph**][25] is a [Dylan][26] subset.  It compiles to JavaScript and has a
quasiquoting macro system, but it again has lots some syntax that doesn't
translate obviously into JS.  Allows macros to be defined in separate modules.
Currently not actively maintained.

### Compilers hosted on other lisps

[**ClojureScript**][27] is a heavy approach; a full [Clojure][28] compiler
targeting JavaScript.  Unlike eslisp, it requires the [JVM][29] and totally
overrides JS' semantics.

[**Parenscript**][30] similarly requires a Common Lisp compiler.  It uses CL
idioms, but is implemented instead as a CL library, allowing it to make a
little more effort than ClojureScript to produce readable JavaScript output.

### Lisp interpreters in JS

[**SLip**][31], [**Javathcript**][32], [**Fargo**][33] (and many others) are
interpreters; they work on internal code representations and so have limited
interoperability with other JavaScript.

## License

[ISC][34].

[1]: http://semver.org/
[2]: https://en.wikipedia.org/wiki/S-expression
[3]: http://en.wikipedia.org/wiki/ECMAScript
[4]: http://stackoverflow.com/questions/267862/what-makes-lisp-macros-so-special
[5]: http://www.catb.org/jargon/html/M/magic.html
[6]: http://en.wikipedia.org/wiki/Syntactic_sugar
[7]: http://en.wikipedia.org/wiki/Abstract_syntax_tree
[8]: http://blog.rongarret.info/2015/05/why-lisp.html
[9]: https://www.npmjs.com/
[10]: https://en.wikipedia.org/wiki/Anaphoric_macro
[11]: http://www.catb.org/jargon/html/H/hack-value.html
[12]: http://en.wikipedia.org/wiki/Conditional_compilation
[13]: http://en.wikipedia.org/wiki/Domain-specific_language
[14]: http://en.wikipedia.org/wiki/Anaphoric_macro
[15]: http://c2.com/cgi/wiki?LispMacro
[16]: http://axisofeval.blogspot.co.uk/2013/04/a-quasiquote-i-can-understand.html
[17]: http://en.wikipedia.org/wiki/PATH_(variable)
[18]: https://developer.mozilla.org/en-US/docs/Mozilla/Projects/SpiderMonkey/Parser_API
[19]: https://github.com/estools/escodegen
[20]: http://jisp.io/
[21]: http://sibilantjs.info/
[22]: http://lispyscript.com/
[23]: https://github.com/Gozala/wisp
[24]: http://clojure.org/
[25]: https://github.com/turbolent/ralph
[26]: http://en.wikipedia.org/wiki/Dylan_(programming_language)
[27]: https://github.com/clojure/clojurescript
[28]: http://clojure.org/
[29]: http://en.wikipedia.org/wiki/Java_virtual_machine
[30]: https://common-lisp.net/project/parenscript/
[31]: http://lisperator.net/slip/
[32]: http://kybernetikos.github.io/Javathcript/
[33]: https://github.com/jcoglan/fargo
[34]: http://opensource.org/licenses/ISC
