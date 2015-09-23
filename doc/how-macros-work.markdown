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
        return [{ atom : '=' }, name, 'hello'];
    };

What it does is probably becoming clear to you without explanation, but let's
say it just in case.  The returned array becomes a list, the returned object
becomes an atom, the string becomes (surprise) still a string, and whatever is
in the `name` argument is plugged in between.

It's basically a template for code of the form `(= <something-goes-here>
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
called with the `yo` atom, the compiler converts it the JS object `{ atom :
"yo" }` and calls the stored function with it.

The function then runs, returning this array:

    [{ atom : '=' }, { atom : "yo" }, 'hello']

The compiler reads the objects as atoms and the array as a list, and adds the
result into the code at that point.  So it's as if you'd written `(= yo
"hello)`.  That compiles to JavaScript to become

    var yo = 'hello';

Yey!

We could of course have written the macro function in eslisp instead:

    (:= (. module exports)
        (function (name) (return (array (object atom "=") name "hello"))))

That compiles to the same JS before.  You can write macros in any language you
want, as long as you can compile it to JS before `require`-ing it from eslisp.

Eslisp has special syntax for making macros super pretty though, so let's talk
about that next:

## Prettier macros with quasiquote

To make macros clearer to read, eslisp has special syntax for returning stuff
that represents code.  Let's rewrite the previous hello-assigning macro:

    (:= (. module exports)
        (function (name) (return `(= ,name "hello"))))

That does exactly the same thing, but it contains less of the `array`/`object`
fluff, so it's clearer to read.  The `array` constructor is replaced with a `` ` `` (backtick).  The `=` atom no longer needs to be written explicitly as
`(object atom =)` and there's now a `,` (comma) before `name`.

In various other Lisp family languages that eslisp is inspired by, the backtick
is called a *quasiquote* and the comma is called *unquote*.  There's a lot of
historical weight behind them and they're pretty good names, so let's roll with
them.

Quasiquote (`` ` ``) means "I want the following thing to represent code".
Inside it, everything is treated as if it were code.  Unquote inside a
quasiquote means "…except this", so unquoted things get inserted as-is.

In fact, the above thing using quasiquote and unquote compiles to

    module.exports = function (name) {
        return Array.prototype.concat([{ atom: '=' }], [name], ['hello']);
    };

Unquote (`,`) also has a cousin called unquote-splicing `,@` which can insert
an array of stuff all at once.

For example, if you want to create a shorthand `mean` for calculating the mean
of some numbers, you could do

    (macro mean
     (function ()
      ; convert arguments to Array
      (= args ((. Array prototype slice call) arguments 0))
      (= total (. args length))
      (return `(/ (+ ,@args) ,total))))

    (mean 1 2 3) ; call it

which effectively creates the eslisp code `(/ (+ 1 2 3) 3)` that compiles to JS
as `(1 + (2 + 3)) / 3;`

If we had used the plain unquote (`,`) instead of unquote-splicing (`,@`), we'd
have gotten `(/ (+ (1 2 3)) 3)` which would compile to nonsense JS, as `1`
isn't a function.

If you don't want to use `quasiquote`/`` ` `` & co., and think it's clearer for
your use-case to just return arrays and objects, you can always do that.

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
    (macro one (function () (return '1)))

    (function ()
      ; Redefine the macro in an inner scope
      (macro one (function () (return '1.1))) ; "very large value of 1"

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

    (macro ninja (function () (return `stealthMode))) ; define macro
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

Macros defined with `macro` do not capture user-defined macros—they effectively
exist in a new, independent scope.

<!-- !test in non-capturing macro -->

    ; Define a macro "ok".
    (macro ok (function () (return 'null)))

    ; Define a non-capturing macro that expects "ok" not to be defined.
    (macro callOk (function (x)
      (return `(ok)))) ; expects this to compile to calling a function "ok"

    ; Which it does, despite a macro "ok" being defined!
    (callOk)

<!-- !test out non-capturing macro -->

    ok();

This is to prevent unexpected results when definitions of macros affect the
return valus of later defined ones (which were perhaps defined in another
module by another person).

If you deliberately *do* want the environment to be captured, just use
`capmacro` instead.  This works exactly the same way as `macro` but *doesn't*
reset the macro environment.

<!-- !test in capturing macro -->

    ; Define a macro "ok".C
    (macro ok (function () (return 'null)))

    ; Define a capturing macro.
    (capmacro callOk (function (x)
      (return `(ok)))) ; expects this to compile to calling the macro "ok"
                       ; (NOT the function "ok"!)

    ; Which it does, because the macro "ok" was captured.
    (callOk)

<!-- !test out capturing macro -->

    null;

In summary: Use `macro`, except when you know you need `capmacro`.

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

### `this.multi`

Allows you to return multiple expressions or statements from a macro.  Just
call it with multiple arguments and return that.

<!-- !test in increment twice -->

    (macro incrementTwice
     (function (x) (return ((. this multi) `(++ ,x) `(++ ,x)))))

    (incrementTwice hello)

compiles to

<!-- !test out increment twice -->

    ++hello;
    ++hello;

### `this.evaluate`

Lets you compile and run eslisp code at compile-time.

For example, you might want to pre-compute some expression.

<!-- !test in precompute -->

    (macro precompute
     (function (list) (return `,((. this evaluate) list))))

    (precompute (+ 1 2 (* 5 (. Math PI))))

compiles to

<!-- !test out precompute -->

    18.707963267948966;

There are much subtler uses for it than that though…

### `this.gensym`

Generates a new atom with a unique name (a [UUID][3], actually).  Every call to
`this.gensym` produces a unique name.

Good for when you just need a unique name for some "scratch" variable that
shouldn't conflict with anything else.

<!-- !test program ./bin/eslc | head -c -1 \
| sed 's:\\$\\w\\+:$779e98ee_d2cf_413c_b608_c0aa93722ef4:g' -->

<!-- !test in gensym swap -->

    ; Generate the assignments needed to swap the values of two variables
    (macro swap
     (function (varA varB)
      (= swapVar ((. this gensym))) ; Generate a new symbol we can use
      (return ((. this multi)

               ; Save a's value in the swap variable
               `(= ,swapVar a)

               ; Assign b's value to a
               `(:= a b)

               ; Assign the swap variable's value to b
               `(:= b ,swapVar)))))
    (swap x y)

<!-- !test out gensym swap -->

    var $779e98ee_d2cf_413c_b608_c0aa93722ef4 = a;
    a = b;
    b = $779e98ee_d2cf_413c_b608_c0aa93722ef4;

A lot like [Common Lisp's `gensym`][4].

### `this.isExpr`

<!-- !test program ./bin/eslc | head -c -1 -->

Answers the question of "*Would this compile to an expression?*".  As opposed
to a statement, that is.

Handy for things like writing a macro that lets you define functions that
implicitly return the last thing in their bodies if it's an expression.

<!-- !test in implicit-return function -->

    (macro fn (function ()
      (= args ((. Array prototype slice call) arguments))
      (= fnArgs (. args 0))
      (= fnBody ((. args slice) 1))

      (= lastInBody ((. fnBody pop))) ; pop off last thing in body

      (= lastConverted
       (?: ((. this isExpr) lastInBody) ; if it's an expression
           `(return ,lastInBody)        ; convert it to a return statement
           lastInBody))                 ; otherwise just return it as-is

      ((. fnBody push) lastConverted) ; push the maybe-converted thing back on

      ; return the function definition
      (return `(function ,fnArgs ,@fnBody))))

    (fn (a b) (+ a b))

<!-- !test out implicit-return function -->

    (function (a, b) {
        return a + b;
    });

[1]: https://github.com/anko/eslisp-camelify
[2]: https://github.com/anko/eslisp-propertify
[3]: http://en.wikipedia.org/wiki/Universally_unique_identifier
[4]: https://www.cs.cmu.edu/Groups/AI/html/cltl/clm/node110.html
