# eslisp [![](https://img.shields.io/npm/v/eslisp.svg?style=flat-square)][1] [![](https://img.shields.io/travis/anko/eslisp.svg?style=flat-square)][2] [![](https://img.shields.io/badge/chat-gitter_%E2%86%92-blue.svg?style=flat-square)][3]

An [S-expression][4] syntax for [ECMAScript][5]/JavaScript, with [Lisp-like
hygienic macros][6].  Minimal core, maximally customisable.

This is not magic:  It's just an S-expression encoding of the [estree][7] AST
format.  The macros are ordinary JS functions that return objects, which just
exist at compile-time.  This means macros can be put on [npm][8] to distribute
your own language features, [like this][9].

> :warning: **Note the 0.x.x [semver][10].**  The API may shift under your
> feet.

## Philosophy

-   **Small core, close to JS**.  This core eslisp corresponds closely with the
    [estree][11] abstract syntax tree format, and hence matches output JS
    clearly.  It's purely a syntax adapter unless you use macros.

-   **Maximum user control**.  Users must be able to easily extend the language
    to their needs, and to publish their features independently of the core
    language.

    User-defined macros must be treated like built-in ones, and are just
    ordinary JS functions.  This means you can write them in anything that
    compiles to JavaScript, put them on [npm][12], and `require` them.

## Motivating example

Here's an example of implementing conditional compilation in eslisp:

<!-- !test program DEBUG=1 ./bin/eslc | head -c -1 -->

<!-- !test in fib -->

    ; Macros are functions bound to names, which operate on code.  This one
    ; checks whether the `$DEBUG` environment variable is set, and if so,
    ; returns a call to `console.log` that also includes a string of the code
    ; that was passed in.
    (macro debug
     (lambda (expression)
      (if (. process env DEBUG)
        (return `((. console log)
                  ; Compile the input expression to JavaScript, and convert
                  ; that to a string.
                  ,((. this string)
                    ((. this compileToJs)
                     ((. this compile) expression)))
                  "="
                  ,expression))
       (return null))))

    (var fib ; Fibonacci number sequence
     (lambda (x)

      ; Conditionally compile logging code
      (debug x)

      ; Basic Fibonacci algorithm
      (switch x
       (0 (return 0))
       (1 (return 1))
       (default (return (+ (fib (- x 1)) (fib (- x 2))))))))

Compiled with `DEBUG=1 eslc file.esl`, that compiles to this JavaScript:

<!-- !test out fib -->

    var fib = function (x) {
        console.log('x', '=', x);
        switch (x) {
        case 0:
            return 0;
        case 1:
            return 1;
        default:
            return fib(x - 1) + fib(x - 2);
        }
    };

Note how the generated `console.log` also has *the name of the variable `x` as
a string*.  Try changing the `debug` call to `(debug ((. Math pow) (+ x 1) 2)`
and watch the logging code change to say `Math.pow(x + 1, 2)` also inside the
first string.  (You can edit it in your browser [on runkit
here](https://runkit.com/anko/590b2059e9af030012b47bb8).)

Compiled with just `eslc file.esl`, the logging code disappears:

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

Doing it this way has a few advantages:

 - Your output code is smaller, compared to the usual technique of hiding your
   debug code behind a boolean flag.
 - This actually logs the expression that produced the result.  Can't do that
   in JS without writing it manually every time, because you can't invoke the
   compiler at compile-time.

<!-- !test program ./bin/eslc | head -c -1 -->

## Why?

I wanted JavaScript to be [homoiconic][13] and have modular macros written in
the same language.  I feel like this is the [adjacent possible][14] in that
direction.  [Sweet.js][15] exists for macros, but theyre awkward to write and
aren't JavaScript.  [Various JavaScript lisps][16] exist, but most have
featuritis from trying too hard to be Lisp (rather than just being a JS
syntax), and none have macros that are just JS functions.

I want a language that I can adapt.  When I need [anaphoric conditionals][17],
or [conditional compilation][18] or file content inlining (like [brfs][19]), or
a [domain-specific language][20] for my favourite library, or something insane
that hacks NASA and runs all my while-loops through `grep` during compilation
for some freak reason, I want to be able to create that language feature myself
or `require` it from npm if it exists, and hence make the language better for
that job, and for others doing it in the future.

That's the dream anyway.

S-expressions are also quite conceptually beautiful; they're just nested lists,
minimally representing the [abstract syntax tree][21], and it's widely known
that [they rock][22], so let's use what works.

This has great [hack value][23] too of course.  [Lisp macros][24] are the
coolest thing since mint ice cream.  Do I even need to say that?

Further documentation in [`doc/`][25]:

-   [Language basics reference][26]
-   [Macro-writing tutorial][27]
-   [Module packaging and distribution tutorial][28]
-   [Comparison against other JS-lisps][29]
-   [Using source maps][30]
-   [Using with client-side bundling tools][31]

## Brief tutorial

This is a quick overview of the core language.  See [the basics reference][32]
or the [test suite][33] for a more complete document.

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

    ; The "." macro compiles to property access.
    (. a b)
    (. a b 5 c "yo")

    ; The "+" macro compiles to addition.
    (+ 1 2)

    ; ... and similarly for "-", "*", "/" and "%" as you'd expect from JS.

<!-- !test out simple macros -->

    a.b;
    a.b[5].c['yo'];
    1 + 2;

If the `(. a b)` syntax feels tedious, you might like the [eslisp-propertify][34] transform macro, which lets you write `a.b` instead.

If the first element of a list isn't the name of a macro which is in scope, it
compiles to a function call:

<!-- !test in function call -->

    (a 1)
    (a 1 2)
    (a)

<!-- !test out function call -->

    a(1);
    a(1, 2);
    a();

These can of course be nested:

<!-- !test in nested macros -->

    ; The "=" macro compiles to a variable declaration.
    (var x (+ 1 (* 2 3)))

    ; Calling the result of a property access expression
    ((. console log) "hi")

<!-- !test out nested macros -->

    var x = 1 + 2 * 3;
    console.log('hi');

### More complex built-in macros

Conditionals are built with the `if` macro:

<!-- !test in special form -->

    ; The "if" macro compiles to an if-statement
    (if lunchtime                 ; argument 1 becomes the conditional
        (block
          (var lunch (find food)) ; argument 2 the consequent
          (lunch))
        (writeMoreCode))          ; argument 3 (optional) the alternate

<!-- !test out special form -->

    if (lunchtime) {
        var lunch = find(food);
        lunch();
    } else
        writeMoreCode();

Note how the block statement (`(block ...)`) has to be made explicit.  Because
it's so common, other macros that accept a block statement as their last
argument have sugar for this: they just assume you meant the rest to be in a
block.

For example. the `lambda` macro (which creates function expressions) treats its
first argument as a list of the function's argument names, and the rest as
statements in the body.

<!-- !test in func and call -->

    (var f (lambda (x)
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

    (var n 10)
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

    (var n 10)
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
are treated equivalently.

**There's a [fuller tutorial to eslisp macros in the `doc/` directory][35].**
These are just some highlights.

You can alias macros to names you find convenient, or mask any you don't want
to use.

<!-- !test in macro aliasing -->

    (macro a array)
    (a 1)
    (array 1)     ; The original still works though...

    (macro array) ; ...unless we deliberately mask it
    (array 1)

<!-- !test out macro aliasing -->

    [1];
    [1];
    array(1);

Macros can use [`quasiquote`][36] (`` ` ``), `unquote` (`,`) and
`unquote-splicing` (`,@`) to construct their outputs neatly.

<!-- !test in macro and call -->

    (macro m (lambda (x) (return `(+ ,x 2))))
    ((. console log) (m 40))

<!-- !test out macro and call -->

    console.log(40 + 2);

The macro function is called with a `this` context containing methods handy for
working with macro arguments, such as `this.evaluate`, which compiles and runs
the argument and returns the result, and `this.atom` which creates a new
S-expression atom.

<!-- !test in evaluate in macro -->

    (macro add2 (lambda (x)
                 (var xPlusTwo (+ ((. this evaluate) x) 2))
                 (return ((. this atom) xPlusTwo))))
    ((. console log) (add2 40))

<!-- !test out evaluate in macro -->

    console.log(42);

You can return multiple statements from a macro by returning an array.

<!-- !test in multiple-return macro -->

    (macro log-and-delete (lambda (varName)
     (return (array
              `((. console log) ((. JSON stringify) ,varName))
              `(delete ,varName)))))

    (log-and-delete someVariable)

<!-- !test out multiple-return macro -->

    console.log(JSON.stringify(someVariable));
    delete someVariable;

Returning `null` from a macro just means nothing.  This is handy for
compilation side-effects and conditional compilation.

<!-- !test in nothing-returning macro -->

    ; Only include statement if `$DEBUG` environment variable is set
    (macro debug (lambda (statement)
     (return (?: (. process env DEBUG) statement null))))

    (debug ((. console log) "debug output"))
    (yep)

<!-- !test out nothing-returning macro -->

    yep();

Because macros are JS functions and JS functions can be closures, you can even
make macros that share state.  One way is to put them in an
[immediately-invoked function expression (IIFE)][37], return them in an object,
and pass that to `macro`.  Each property of the object is imported as a macro,
and the variables in the IIFE are shared between them.

<!-- !test in macros block -->

    (macro ((lambda ()
            (var x 0) ; visible to all of the macro functions
            (return
             (object increment (lambda () (return ((. this atom) (++ x))))
                     decrement (lambda () (return ((. this atom) (-- x))))
                     get       (lambda () (return ((. this atom) x))))))))

    (increment)
    (increment)
    (increment)

    (decrement)

    (get)

<!-- !test out macros block -->

    1;
    2;
    3;
    2;
    2;

### Macros as modules

The second argument to `macro` needs to evaluate to a function, but it can be
whatever, so you can put the macro function in a separate file and do—

    (macro someName (require "./file.js"))

—to use it.

This means you can publish eslisp macros on [npm][38].  The name prefix
`eslisp-` and keyword `eslisp-macro` are recommended.  [Some exist
already.][39]

### Transformation macros

When running `eslc` from the command line, to apply a transformation macro to
an eslisp file during compilation, supply the `--transform <macro-name>`
argument (`-t` for short). For example,

    eslc --transform eslisp-propertify myprogram.esl

uses [eslisp-propertify][40] to convert all atoms containg dots into member
expressions.  The flag can be specified multiple times.

## Try it

### Global install

If you want `eslc` in your [`$PATH`][41], `npm install --global eslisp`.  (You
might need `sudo`.)  Then `eslc` program takes eslisp code as input and outputs
JavaScript.

If run interactively without arguments, the compiler loads a [REPL][42] that
you can type commands into to test them.

You can also just pipe data to it to compile it if you want.

    echo '((. console log) "Yo!")' | eslc

Or pass a filename, like `eslc myprogram.esl`.

To remove it cleanly, `npm uninstall --global eslisp`.

### Local install

If you want the compiler in `node_modules/.bin/eslc`, do `npm install eslisp`.

You can also use eslisp as a module: it exports a function that takes a string
of eslisp code as input and outputs a string of JavaScript, throwing errors if
it sees them.

## How does it work

In brief:  A table of predefined macros is used to turn S-expressions into
[SpiderMonkey AST][43], which is fed to [escodegen][44], which outputs JS.
Some of those macros allow defining further macros, which get added to the
table and work from then on like the predefined ones.

For more, read [the source][45]. Ask questions!

## Bugs, discussion & contributing

Create a [github issue][46], or say hi [in gitter chat][47].

I'll assume your contributions to also be under the [ISC license][48].

## License

[ISC][49].

[1]: https://www.npmjs.com/package/eslisp
[2]: https://travis-ci.org/anko/eslisp
[3]: https://gitter.im/anko/eslisp
[4]: https://en.wikipedia.org/wiki/S-expression
[5]: http://en.wikipedia.org/wiki/ECMAScript
[6]: http://stackoverflow.com/questions/267862/what-makes-lisp-macros-so-special
[7]: https://github.com/estree/estree
[8]: https://www.npmjs.com/
[9]: https://www.npmjs.com/search?q=eslisp-
[10]: http://semver.org/spec/v2.0.0.html
[11]: https://www.npmjs.com/
[12]: https://www.npmjs.com/
[13]: http://en.wikipedia.org/wiki/Homoiconicity
[14]: http://www.wsj.com/articles/SB10001424052748703989304575503730101860838
[15]: http://sweetjs.org/
[16]: doc/comparison-to-other-js-lisps.markdown
[17]: https://en.wikipedia.org/wiki/Anaphoric_macro
[18]: http://en.wikipedia.org/wiki/Conditional_compilation
[19]: https://github.com/substack/brfs
[20]: http://en.wikipedia.org/wiki/Domain-specific_language
[21]: http://en.wikipedia.org/wiki/Abstract_syntax_tree
[22]: http://blog.rongarret.info/2015/05/why-lisp.html
[23]: http://www.catb.org/jargon/html/H/hack-value.html
[24]: http://c2.com/cgi/wiki?LispMacro
[25]: doc/
[26]: doc/basics-reference.markdown
[27]: doc/how-macros-work.markdown
[28]: doc/ditributing-modules.markdown
[29]: doc/comparison-to-other-js-lisps.markdown
[30]: doc/source-maps.markdown
[31]: doc/bundling.markdown
[32]: doc/basics-reference.markdown
[33]: test.ls
[34]: https://www.npmjs.com/package/eslisp-propertify
[35]: doc/how-macros-work.markdown
[36]: http://axisofeval.blogspot.co.uk/2013/04/a-quasiquote-i-can-understand.html
[37]: https://en.wikipedia.org/wiki/Immediately-invoked_function_expression
[38]: https://www.npmjs.com/
[39]: https://www.npmjs.com/search?q=eslisp-
[40]: https://www.npmjs.com/package/eslisp-propertify
[41]: http://en.wikipedia.org/wiki/PATH_(variable)
[42]: https://en.wikipedia.org/wiki/Read%E2%80%93eval%E2%80%93print_loop
[43]: https://developer.mozilla.org/en-US/docs/Mozilla/Projects/SpiderMonkey/Parser_API
[44]: https://github.com/estools/escodegen
[45]: src/
[46]: https://github.com/anko/eslisp/issues/new
[47]: https://gitter.im/anko/eslisp
[48]: http://opensource.org/licenses/ISC
[49]: http://opensource.org/licenses/ISC
