# eslisp [![](https://img.shields.io/npm/v/eslisp.svg?style=flat-square)][1] [![](https://img.shields.io/travis/anko/eslisp.svg?style=flat-square)][2] [![](https://img.shields.io/badge/chat-gitter_%E2%86%92-blue.svg?style=flat-square)][3]

An [S-expression][4] syntax for [ECMAScript][5]/JavaScript, with [Lisp-like
hygienic macros][6] and modular syntax.

This is not magic:  It's literally just an S-expression encoding of the
[estree][7] AST format.  The macros are ordinary JS functions that return lists
and run at compile-time, and can be put on [npm][8].

> **Caution of moving floor**: Eslisp follows [semver][9] and we're still on
> unstable (0.x.x).  Things may shift under your feet.
> 
> Until 1.0.0, patch version bumps usually imply bugfixes or new features, and
> minor versions bumps break the API.

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

-   **Small core, close to JS**.  This core eslisp corresponds closely with the
    [estree][10] abstract syntax tree format, and hence matches output JS
    clearly.  It's purely a syntax adapter unless you use macros.

-   **Maximum user control**.  Users must be able to easily extend the language
    to their needs, and to publish their features independently of the core
    language.

    User-defined macros are treated like built-in ones, and are just ordinary
    JS functions.  This means you can write them in anything that compiles to
    JavaScript, put them on [npm][11], and `require` them.


## Why?

I wanted JavaScript to be [homoiconic][12] and have modular macros written in
the same language.  I feel like this is the [adjacent possible][13] in that
direction.  [Sweet.js][14] exists for macros, but theyre awkward to write and
aren't JavaScript.  [Various JavaScript lisps][15] exist, but most have
featuritis from trying too hard to be Lisp (rather than just being a JS
syntax), and none have macros that are just JS functions.

I want a language that I can adapt.  When I need [anaphoric conditionals][16],
or [conditional compilation][17] or file content inlining (like [brfs][18]), or
a [domain-specific language][19] for my favourite library, or something insane
that hacks NASA and runs all my while-loops through `grep` during compilation
for some freak reason, I want to be able to create that language feature myself
or `require` it from npm if it exists, and hence make the language better for
that job, and for others doing it in the future.

That's the dream anyway.

S-expressions are also quite conceptually beautiful; they're just nested lists,
minimally representing the [abstract syntax tree][20], and it's widely known
that [they rock][21], so let's use what works.

This has great [hack value][22] too of course.  [Lisp macros][23] are the
coolest thing since mint ice cream.  Do I even need to say that?

Further documentation in [`doc/`][24]:

-   [Comparison against other JS-lisps][25]
-   [Tutorial for module packaging and distribution][26]
-   [Tutorial for macros][27]

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

**There's a [fuller tutorial to eslisp macros in the `doc/` directory][28].**
This is just some representative bits.

Macros can [`quasiquote`][29] (`` ` ``) and `unquote` (`,`) values into their
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
[immediately-invoked function expression (IIFE)][30] to `macro` and return an
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

This means you can publish eslisp macros on [npm][31].  The name prefix
`eslisp-` is recommended.

## Try it

Clone this repo and `npm install` to get the compiler in `bin/eslc`.  Pipe
eslisp to it. Receive ECMAScript.

    echo '((. console log) "Yo!")' | ./bin/eslc

[The tests][32] are basically a language tutorial.

If you want `eslc` in your [`$PATH`][33], `npm install --global`.

To remove it cleanly, `npm uninstall --global`.

## How does it work

A table of predefined macros is used to turn S-expressions into [SpiderMonkey
AST][34], which is fed to [escodegen][35], which outputs JS.  Some of those
macros allow defining further macros, which get added to the table and
henceforth work just like the predefined ones do.

The [brief comparison to other JS lisp-likes][36] might be interesting too.

## Bugs & contributing

Create a [github issue][37], or say hi [in gitter chat][38].

I'll assume your contributions to also be under the [ISC license][39].

## License

[ISC][40].

[1]: https://www.npmjs.com/package/eslisp
[2]: https://travis-ci.org/anko/eslisp
[3]: https://gitter.im/anko/eslisp
[4]: https://en.wikipedia.org/wiki/S-expression
[5]: http://en.wikipedia.org/wiki/ECMAScript
[6]: http://stackoverflow.com/questions/267862/what-makes-lisp-macros-so-special
[7]: https://github.com/estree/estree
[8]: https://www.npmjs.com/
[9]: http://semver.org/spec/v2.0.0.html
[10]: https://www.npmjs.com/
[11]: https://www.npmjs.com/
[12]: http://en.wikipedia.org/wiki/Homoiconicity
[13]: http://www.wsj.com/articles/SB10001424052748703989304575503730101860838
[14]: http://sweetjs.org/
[15]: doc/comparison-to-other-js-lisps.markdown
[16]: https://en.wikipedia.org/wiki/Anaphoric_macro
[17]: http://en.wikipedia.org/wiki/Conditional_compilation
[18]: https://github.com/substack/brfs
[19]: http://en.wikipedia.org/wiki/Domain-specific_language
[20]: http://en.wikipedia.org/wiki/Abstract_syntax_tree
[21]: http://blog.rongarret.info/2015/05/why-lisp.html
[22]: http://www.catb.org/jargon/html/H/hack-value.html
[23]: http://c2.com/cgi/wiki?LispMacro
[24]: doc/
[25]: doc/comparison-to-other-js-lisps.markdown
[26]: doc/ditributing-modules.markdown
[27]: doc/how-macros-work.markdown
[28]: doc/how-macros-work.markdown
[29]: http://axisofeval.blogspot.co.uk/2013/04/a-quasiquote-i-can-understand.html
[30]: https://en.wikipedia.org/wiki/Immediately-invoked_function_expression
[31]: https://www.npmjs.com/
[32]: https://github.com/anko/eslisp/blob/master/test.ls
[33]: http://en.wikipedia.org/wiki/PATH_(variable)
[34]: https://developer.mozilla.org/en-US/docs/Mozilla/Projects/SpiderMonkey/Parser_API
[35]: https://github.com/estools/escodegen
[36]: doc/comparison-to-other-js-lisps.markdown
[37]: https://github.com/anko/eslisp/issues/new
[38]: https://gitter.im/anko/eslisp
[39]: http://opensource.org/licenses/ISC
[40]: http://opensource.org/licenses/ISC
