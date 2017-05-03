# How eslisp macros work (a tutorial)

Macros are functions that only exist at compile-time.  You define them a little
differently, but call them the same way as normal functions.  They can execute
whatever logic you want, and their return values become program code at the
point where they're called.

<!-- !test program ./bin/eslc | head -c -1 -->

## The basics

Here's a macro in JavaScript which returns code for declaring a variable of a
given `name` with the value `"hello"`:

    module.exports = function (name) {
        return this.list(this.atom('var'), name, this.string('hello'));
    };

That returns a list which first element is an atom, the second is the first
argument passed to the macro, and the third is a string.

It's basically a template for code of the form `(var <something-goes-here>
"hello")`.

Let's save that in `declareAsHello.js` and `require` it from eslisp code
somewhere in the same directory, so we can talk through what's happening:

    ; Construct a macro by binding the function to a name.
    ; The `macro` constructor expects to be given 2 arguments:
    ;
    ;  - a name for the macro
    ;  - something that evaluates to a function
    ;
    (macro declareAsHello (require "declareAsHello.js"))

    ; Call it with its name, with the atom `yo` as an argument.
    ; Yes, it looks just like a function call.  This is on purpose.
    ; Its result gets translated to code and put here.
    (declareAsHello yo)

The compiler evaluates the `(require "declareAsHello.js")`, checks it got a
function and saves it as a macro under the given name.  When that macro is
called with the `yo` atom, the compiler calls the stored function with it.

The function then runs, returning S-expression nodes equivalent to

    (var yo "hello")

The compiler then sees that a `var` macro is defined, so it calls that, which
emits the code

    var yo = 'hello';

Yey!

We could of course have written the macro function in eslisp instead:

    (= (. module exports)
       (lambda (name)
        (return ((. this list)
                 ((. this atom) "=")
                 name
                 ((. this string) "hello")))))

That compiles to the same JS before.  In fact, you can write macros in any
language you want, as long as you can compile it to JS before `require`-ing it
from eslisp.

If the above syntax looks clumsy, that's because it is.  Eslisp has special
syntax for *quoting*, which makes macro return values much easier to read:

## Prettier macros with quasiquote

To make macros clearer to read, eslisp has special syntax for returning stuff
that represents code.  Let's rewrite the previous hello-assigning macro:

    (= (. module exports) (lambda (name) (return `(var ,name "hello"))))

That does exactly the same thing, but it contains less of the
`atom`/`list`/`string` constructor fluff, so it's clearer to read.  The `(.
this list)` constructor is replaced with a `` ` `` (backtick).  The `var` atom
no longer needs to be written explicitly as `((. this atom) var)` and there's
now a `,` (comma) before `name`.

In various other Lisp family languages that eslisp is inspired by, the backtick
is called a *quasiquote* and the comma is called *unquote*.  There's a lot of
historical weight behind them and they're pretty good names, so let's roll with
them.

Quasiquote (`` ` ``) means "I want the following thing to represent code".
Inside it, everything is treated as if it were code.  Unquote inside a
quasiquote means "…except this", so unquoted things get inserted as-is.

In fact, the above thing using quasiquote and unquote compiles to something
like

    module.exports = function (name) {
      return {
        type : "list",
        values : Array.prototype.concat(
          [ { type : "atom", value : "var" } ],
          [ name ],
          [ { type : "string" value : "hello" ]
        )
      };
    };

Unquote (`,`) also has a cousin called unquote-splicing `,@` which can insert
an array of stuff all at once.

For example, if you want to create a shorthand `mean` for creating the
expression necessary to calculate the mean of some variables, you could do

<!-- !test in mean macro -->

    (macro mean
     (lambda ()

      ; Convert arguments object to an array
      (var argumentsAsArray ((. Array prototype slice call) arguments 0))

      ; Make an eslisp list object from the arguments
      (var args ((. this list apply) null argumentsAsArray))

      ; Make an eslisp atom representing the number of arguments
      (var total ((. this atom) (. arguments length)))

      ; Return a division of the sum of the arguments by the total
      (return `(/ (+ ,@args) ,total))))

    (mean 1 2 a)

which effectively creates the eslisp code `(/ (+ 1 2 a) 3)` that compiles to JS
as—

<!-- !test out mean macro -->

    (1 + 2 + a) / 3;

If we had used the plain unquote (`,`) instead of unquote-splicing (`,@`), we'd
have gotten `(/ (+ (1 2 a)) 3)` which would compile to nonsense JS, as eslisp
would think `(1 2 a)` was a function call when `1` isn't a function.

If you don't want to use `quasiquote`/`` ` `` & co., and think it's clearer for
your use-case to just work with objects, you can still always do that.

## Scope

### Aliasing

If you don't like the names of predefined macros, or you for any reason want to
use a different name, you can pass two identifiers to `macro` to alias the
second to the first.

<!-- !test in macro aliasing -->

    (macro plus +)
    (plus 0 1)

<!-- !test out macro aliasing -->

    0 + 1;

### Nesting, redefinition and masking

Redefinition of a macro masks the older one.

Macros can be defined wherever eslisp expects multiple expressions or
statements.  For example, in a function expression's body.  Macros defined in
inner scopes like that go out of scope (as in, disappear) at the end of that
list.

<!-- !test in function-expression scope macro -->

    ; Define at root scope
    (macro one (lambda () (return '1)))

    (lambda ()
      ; Redefine the macro in an inner scope
      (macro one (lambda () (return '1.1))) ; "very large value of 1"

      ((. console log) (one)))

    ((. console log) (one))

<!-- !test out function-expression scope macro -->

    (function () {
        console.log(1.1);
    });
    console.log(1);

You can also deliberately mask a macro with *nothing*, which means that macro
is treated as if it didn't exist.  This likewise persists only at the current
nesting level.

<!-- !test in scoped macro masking -->

    (macro ninja (lambda () (return `stealthMode))) ; define macro
    (if seriousBusiness                               ; in inner scope...
        (block (macro ninja)                          ;   mask it
               (ninja)))                              ;   function call
    (ninja)                                           ; macro call

<!-- !test out scoped macro masking -->

    if (seriousBusiness) {
        ninja();
    }
    stealthMode;

### Using macros inside macros

The return values of macros can call other macros too.

Redefinition of a macro in the outer environment is reflected in how
earlier-defined macros are processed.

<!-- !test in used macro redefinition -->

    (macro best (lambda () (return 'pirates)))

    (macro callBest (lambda (x)
      (return `(best))))

    (callBest)

    (macro best (lambda () (return 'ninjas))) ; redefinition

    (callBest)

<!-- !test out used macro redefinition -->

    pirates;
    ninjas;

If you're absolutely sure you really do want to return a call expression
`best()` without expanding the macro, you should return an estree object,
because those aren't macro-expanded.

## Transform macros

If you want to wrap *a whole file* in a macro (or many macros) and do some
radical global transformations, that's what the compiler's `--transform`/`-t`
flag is about.

Transform macros are written just like any other macro, but when specified like
that from the command line (e.g. `eslc -t eslisp-propertify`), they're each run
in a separate compilation environment, so they can't interfere with each other
and don't unnecessarily stick around in the macro table.

For examples of how to write them, check out [eslisp-camelify][1] or
[eslisp-propertify][2].

## Macro helpers (stuff in `this`)

When macros are called, the function associated with them is called with a
particular `this`-context, such that the `this` object contains properties with
various handy helper functions:

### `this.evaluate`

Lets you compile and run eslisp code at compile-time.

For example, here's how you might pre-compute a numeric expression at
compile-time:

<!-- !test in precompute -->

    (macro precompute
     (lambda (list) (return ((. this atom) ((. this evaluate) list)))))

    (precompute (+ 1 2 (* 5 (. Math PI))))

compiles to

<!-- !test out precompute -->

    18.707963267948966;

[1]: https://github.com/anko/eslisp-camelify
[2]: https://github.com/anko/eslisp-propertify
