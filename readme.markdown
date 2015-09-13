# eslisp [![](https://img.shields.io/npm/v/eslisp.svg?style=flat-square)][1] [![](https://img.shields.io/travis/anko/eslisp.svg?style=flat-square)][2] [![](https://img.shields.io/badge/chat-gitter_%E2%86%92-blue.svg?style=flat-square)][3]

[S-expression][4] syntax for [ECMAScript][5]/JavaScript, with [lisp-like
macros][6].  Unopinionated and easily extensible.  Minimum [magic][7] or
[sugar][8].

<!-- !test program ./bin/eslc | head -c -1 -->

<!-- !test in fib -->

    ; Only include given statement if `$DEBUG` environment variable is set
    (macro debug
     (function (statement)
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

Further documentation in [`doc/`][21]:

-   [Comparison against other JS-lisps][22]
-   [Tutorial for module packaging and distribution][23]
-   [Tutorial for macros][24]

Versioning follows [semver][25].

## Brief tutorial

### Building blocks

Eslisp code consists of comments, atoms, strings and lists.

    ; Everything from a semicolon to the end of a line is a comment.

    hello           ; This is an atom.
    "hello"         ; This is a string.
    (hello "hello") ; This is a list containing an atom and a string.
    ()              ; This is an empty list.

Lists describe the code structure.  Whitespace is insignificant.

    (these mean (the same) thing)

    (these
    mean (the
    same) thing)

    (these    mean (the
                    same) thing)

All eslisp code is constructed by calling macros at compile-time.  There are
built-in macros to generate JavaScript operators, loop structures, expressions,
statements… everything needed to write arbitrary JavaScript.

### Some simple built-in macros

A macro is called by writing a list with its name as the first element and its
arguments as the rest:

<!-- !test in simple macros -->

    ; Everything from a semicolon to the end of a line is a comment.

    ; The "." macro compiles to property access.
    (. a b)
    (. a b 5 c "yo")

    ; The "+" macro compiles to addition.
    (+ 1 2)

    ; ... and similarly for "-", "*", "/" and "%".

<!-- !test out simple macros -->

    a.b;
    a.b[5].c['yo'];
    1 + 2;

If the first element of a list isn't a macro name, it compiles to a function
call:

<!-- !test in function call -->

    (a 1)
    (a 1 2)
    (a)

<!-- !test out function call -->

    a(1);
    a(1, 2);
    a();

They can of course be nested:

<!-- !test in nested macros -->

    ; The "=" macro compiles to a variable declaration.
    (= x (+ 1 (* 2 3)))

    ; Calling the result of a property access expression
    ((. console log) "hi")

<!-- !test out nested macros -->

    var x = 1 + 2 * 3;
    console.log('hi');

### More complex built-in macros

Some macros treat their arguments specially.  For example, the `if` macro
expects its first argument to return a conditional expression, and its second
and third arguments to be lists of statements that go in the consecutive and
alternate blocks respectively.

<!-- !test in special form -->

    ; The "if" macro compiles to an if-statement.
    (if ok              ; It treats the first argument as the conditional,
        (block          ; the second as the consequent,
          (= x (! ok))  ;     (note that blocks must be explicit)
          (return x))
        (return false)) ; and the (optional) third as the alternate.

<!-- !test out special form -->

    if (ok) {
        var x = !ok;
        return x;
    } else
        return false;

In most macros though, you don't have to declare the block statement explicitly like that.

For example. the `function` macro treats its first argument as a list
of the function's argument names, and the rest as statements in the
function body.

<!-- !test in func and call -->

    (= f (function (x)
          (a x)
          (return (+ x 2))))
    (f 40)

<!-- !test out func and call -->

    var f = function (x) {
        a(x);
        return x + 2;
    };
    f(40);

While-loops similarly.

<!-- !test in while loop -->

    (= n 10)
    (while (-- n)   ; first argument is loop conditional
     (hello n)      ; the rest are loop-body statements
     (hello (- n 1)))

<!-- !test out while loop -->

    var n = 10;
    while (--n) {
        hello(n);
        hello(n - 1);
    }

You *can* use an explicit block statements (`(block ...)`) wherever implicit
ones are allowed, if you want to.

<!-- !test in while loop with explicit block -->

    (= n 10)
    (while (-- n)
     (block (hello n)
            (hello (- n 1))))

<!-- !test out while loop with explicit block -->

    var n = 10;
    while (--n) {
        hello(n);
        hello(n - 1);
    }

### Writing your own macros

This is what eslisp is really for.

Macros are functions that run at compile-time.  Whatever they return becomes
part of the compiled code.  User-defined macros and pre-defined compiler ones
are treated equivalently.  You can define as literally just JavaScript
functions that return stuff.

**There's a [fuller tutorial to eslisp macros in the `doc/` directory][26].**
This is just some representative bits.

Macros can [`quasiquote`][27] (`` ` ``) and `unquote` (`,`) values into their
outputs and perform arbitrary computations.

<!-- !test in macro and call -->

    (macro m (function (x) (return `(+ ,x 2))))
    ((. console log) (m 40))

<!-- !test out macro and call -->

    console.log(40 + 2);

The function is called with a `this` context containing methods handy for
working with macro arguments, such as `this.evaluate`, which compiles and runs
the argument and returns the result.

<!-- !test in evaluate in macro -->

    (macro m2 (function (x) (return `,(+ ((. this evaluate) x) 2))))
    ((. console log) (m2 40))

<!-- !test out evaluate in macro -->

    console.log(42);

You can return multiple statements from a macro with `this.multi`.

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
[immediately-invoked function expression (IIFE)][28] to `macro` and return an
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

### Macros as modules

The second argument to `macro` needs to evaluate to a function, but it can be
whatever. so you can put the macro function in a separate file and do `(macro
someName (require "./file.js"))` to use it.

This means you can publish eslisp macros on [npm][29].  The name prefix `esl-`
is recommended.

## Try it

Clone this repo and `npm install` to get the compiler in `bin/eslc`.  Pipe
eslisp to it. Receive ECMAScript.

    echo '((. console log) "Yo!")' | ./bin/eslc

[The tests][30] are basically a language tutorial.

If you want `eslc` in your [`$PATH`][31], `npm install --global`.

To remove it cleanly, `npm uninstall --global`.

## How does it work

A table of predefined macros is used to turn S-expressions into [SpiderMonkey
AST][32], which is fed to [escodegen][33], which outputs JS.  Some of those
macros allow defining further macros, which get added to the table and
henceforth work just like the predefined ones do.

The [brief comparison to other JS lisp-likes][34] might be interesting too.

## Bugs & contributing

Create a [github issue][35], or come say hi [in gitter chat][36].  Ideas and
questions warmly welcomed.

For pull requests, I'll assume you're OK with releasing your contributions
under the ISC license.

## License

[ISC][37].

[1]: https://www.npmjs.com/package/eslisp
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
[21]: doc/
[22]: doc/comparison-to-other-js-lisps.markdown
[23]: doc/ditributing-modules.markdown
[24]: doc/how-macros-work.markdown
[25]: http://semver.org/spec/v2.0.0.html
[26]: doc/how-macros-work.markdown
[27]: http://axisofeval.blogspot.co.uk/2013/04/a-quasiquote-i-can-understand.html
[28]: https://en.wikipedia.org/wiki/Immediately-invoked_function_expression
[29]: https://www.npmjs.com/
[30]: https://github.com/anko/eslisp/blob/master/test.ls
[31]: http://en.wikipedia.org/wiki/PATH_(variable)
[32]: https://developer.mozilla.org/en-US/docs/Mozilla/Projects/SpiderMonkey/Parser_API
[33]: https://github.com/estools/escodegen
[34]: doc/comparison-to-other-js-lisps.markdown
[35]: https://github.com/anko/eslisp/issues/new
[36]: https://gitter.im/anko/eslisp
[37]: http://opensource.org/licenses/ISC
