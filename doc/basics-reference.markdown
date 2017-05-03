# Eslisp basics tutorial

This page explains how to read eslisp code and what all the built-in macros do.
If you're particularly interested in how macros work, see [the macro
tutorial][1].

## The compiler

The eslisp package comes with a compiler program `eslc`, which reads eslisp
code on stdin and emits corresponding JavaScript on stdout.

The only particularly interesting flag you can give it is `--transform`/`-t`,
which specifies a [*transform macro*][2] for changing something about the
entire program.  Examples include supporting dash-separated variables
([eslisp-camelify][3]) or shorthand property access ([eslisp-propertify][4]).
These are just for sugar; you can use them if you want.

## Syntax

Eslisp code consists of **S-expressions**.  These are **lists** that may
contain **atoms** or *other lists*.

Examples:

-   In `(+ 1 2)`, the parentheses `()` represent a list, containing three atoms
    `+`, `1` and `2`.

-   `(a (b c))` is a list containing an atom `a` and another list containing
    `b` and `c`.

There are 3 kinds of atom in eslisp:

Atoms with double quotes `"` at both ends are read as **strings**. (e.g.  `"hi"`
or `"39"`.)  All "opened" double quotes must be closed somewhere.

Atoms that consist of number digits (`0`–`9`), optionally with an embedded
decimal dot (`.`) are read as **numbers**.

All other atoms are read as **identifiers**—names for something.

You can also add comments, which run from the character `;` to the end of that
line.

Whitespace is ignored outside of strings, so these 3 programs are equivalent:

    (these mean (the same) thing)

<!-- -->

    (these
    mean (the
    same) thing)

<!-- -->

    (these mean (the
                 same) thing)

This means you can indent your code as you wish.  There are [conventions][5]
that other languages using S-expression syntax use, which may make it easier
for others to read your code.  This tutorial will stick to those conventions.

That's all you need to know about the syntax to get started.  (There is a
little extra syntax that makes *macros* easier to write, but we'll talk about
those later.)

## Compilation

<!-- !test program ./bin/eslc | head -c -1 -->

When you hand your code to the eslisp compiler, it reads the lists and turns
them into JavaScript code with the following rules:

-   Strings become JavaScript strings.

    <!-- !test in string compilation -->

        "hi"

    <!-- !test out string compilation -->

        'hi';

-   Numbers become JavaScript numbers.

    <!-- !test in number compilation -->

        42.222

    <!-- !test out number compilation -->

        42.222;

-   Identifiers become JavaScript indentifiers.

    <!-- !test in identifier compilation -->

        helloThere

    <!-- !test out identifier compilation -->

        helloThere;

-   Lists where the first element is *an identifier that matches a macro*
    becomes the output of that macro when called with the rest of the elements.

    Here `+` is a built-in macro that compiles its arguments and outputs a
    JavaScript addition expression:

    <!-- !test in macro compilation -->

        (+ 1 2)

    <!-- !test out macro compilation -->

        1 + 2;

-   Any other list becomes a JavaScript function call

    <!-- !test in function call compilation -->

        (split word ",")

    <!-- !test out function call compilation -->

        split(word, ',');


Nested lists work the same way, unless the macro that they are a parameter of
chooses otherwise.

That's all.

## Built-in macros

Macros are functions that only exist at compile-time.  A minimal set needed to
generate arbitrary JavaScript are built in to eslisp.

### Summary

#### Operators

[Arithmetic ops][6]: `+` `-` `*` `/` `%`
<br>Bitwise: `&` `|` `<<` `>>` `>>>` `~`
<br>Logic: `&&` `||` `!`
<br>Comparison: `==`=== `!=` `!==` `<` `>` `>=` `<=`
<br>[Assignment][7]: `=` `+=` `-=` `*=` `/=` `%=` `<<=` `>>=` `>>>=` `&=` `|=` `^=`
<br>[Increment / decrement][8]: `++` `--` `++_` `--_` `_++` `_--`

### General

| name       | description                  |
| ---------- | ---------------------------- |
| `array`    | array literal                |
| `object`   | object literal               |
| `regex`    | regular expression literal   |
| `var`      | variable declaration         |
| `.`        | member expression            |
| `get`      | *computed* member expression |
| `switch`   | switch statement             |
| `if`       | conditional statement        |
| `?:`       | ternary expression           |
| `while`    | while loop                   |
| `dowhile`  | do-while loop                |
| `for`      | for loop                     |
| `forin`    | for-in loop                  |
| `break`    | break statement              |
| `continue` | continue statement           |
| `label`    | labeled statement            |
| `lambda`   | function expression          |
| `function` | function declaration         |
| `return`   | return statement             |
| `new`      | new-expression               |
| `debugger` | debugger statement           |
| `throw`    | throw statement              |
| `try`      | try-catch statement          |

#### Structural

| name    | description               |
| ------- | ------------------------- |
| `seq`   | comma sequence expression |
| `block` | block statement           |

#### Macro-related

| name         | description                           |
| ------------ | ------------------------------------- |
| `macro`      | macro directive                       |
| `capmacro`   | environment-capturing macro directive |
| `quote`      | quotation operator                    |
| `quasiquote` | quasiquote                            |

These are only valid inside `quasiquote`:

| name               | description      |
| ------------------ | ---------------- |
| `unquote`          | unquote          |
| `unquote-splicing` | unquote-splicing |

### Operators

#### Arithmetic

These take 2 or more arguments (except `-`, which can also take 1), and compile
to what you'd expect.

<!-- !test in arithmetic -->

    (+ 1 2 3)
    (- a b)
    (- a)
    (/ 3 4)
    (* 3 (% 10 6))

<!-- !test out arithmetic -->

    1 + 2 + 3;
    a - b;
    -a;
    3 / 4;
    3 * (10 % 6);

Same goes for bitwise arithmetic `&` `|` `<<` `>>` `>>>` and `~`, logic
operators `&&`, `||` and `!` and pretty much everything else in JavaScript.

#### Increment and decrement

`++` and `--` as in JavaScript.  Those compile to prefix (`++x`).  If you want
the postfix operators (`x++`), use `_++`/`_--`.  (`++_`/`--_` also do prefix.)

#### Delete and instanceof

The `delete` and `instanceof` macros correspond to the JS operators of the same
names.

<!-- !test in delete and instanceof -->

    (instanceof a B)
    (delete x)

<!-- !test out delete and instanceof -->

    a instanceof B;
    delete x;

### Declaration and assignment

Variable declaration in eslisp uses the `var` macro, and assignment is `=`.

<!-- !test in declaration and assignment -->

    (var x)
    (var y 1)
    (= y 2)

<!-- !test out declaration and assignment -->

    var x;
    var y = 1;
    y = 2;

The other [assignment operators][9] are the same as in JS.

<!-- !test in shorthand assignment -->

    (-= a 5)
    (&= x 6)

<!-- !test out shorthand assignment -->

    a -= 5;
    x &= 6;

### Arrays and objects

Array literals are created with the `array` macro.  The parameters become
elements.

<!-- !test in array macro -->

    (array)
    (array a 1)

<!-- !test out array macro -->

    [];
    [
        a,
        1
    ];

Object literals are created with the `object` macro which expects its
parameters to be alternating keys and values.

<!-- !test in object macro -->

    (object)
    (object a 1)
    (object "a" 1 "b" 2)

<!-- !test out object macro -->

    ({});
    ({ a: 1 });
    ({
        'a': 1,
        'b': 2
    });

Property access uses the `.` macro.

<!-- !test in property access macro -->

    (. a 1)
    (. a b (. c d))
    (. a 1 "b" c)

<!-- !test out property access macro -->

    a[1];
    a.b[c.d];
    a[1]['b'].c;

If you wish you could just write those as `a.b.c` in eslisp code, use the
[*eslisp-propertify*][10] user-macro.

For *computed* property access, use the `get` macro.

<!-- !test in computed property access macro -->

    (get a b)
    (get a b c 1)
    (= (get a b) 5)

<!-- !test out computed property access macro -->

    a[b];
    a[b][c][1];
    a[b] = 5;

For new-expressions, use the `new` macro.

<!-- !test in new expression -->

    (new a)
    (new a 1 2 3)

<!-- !test out new expression -->

    new a();
    new a(1, 2, 3);

### Conditionals

The `if` macro outputs an if-statement, using the first argument as the
condition, the second as the consequent and the (optional) third as the
alternate.

<!-- !test in if statement -->

    (if a b c)

<!-- !test out if statement -->

    if (a)
        b;
    else
        c;

To get multiple statements in the consequent or alternate, wrap them in the
`block` macro.

<!-- !test in if statement with block -->

    (if a
        (block (+= b 5)
               (f b))
        (f b))

<!-- !test out if statement with block -->

    if (a) {
        b += 5;
        f(b);
    } else
        f(b);

Some macros treat their arguments specially instead of just straight-up
compiling them.

For example, the `switch` macro (which creates switch statements) takes the
expression to switch on as the first argument, but all further arguments are
assumed to be lists where the first element is the case clause and the rest are
the resulting statements.  Observe also that the identifier `default` implies
the `default`-case clause.

<!-- !test in switch statement -->

    (switch x
        (1 ((. console log) "it is 1")
           (break))
        (default ((. console log) "it is not 1")))

<!-- !test out switch statement -->

    switch (x) {
    case 1:
        console.log('it is 1');
        break;
    default:
        console.log('it is not 1');
    }

### Functions

#### Function expressions

The `lambda` macro creates function expressions.  Its first argument becomes
the argument list, and the rest become statements in its body.  The `return`
macro compiles to a return-statement.

<!-- !test in function expression -->

    (var f (lambda (a b) (return (* 5 a b))))

<!-- !test out function expression -->

    var f = function (a, b) {
        return 5 * a * b;
    };

You can also give a name to a function expression as the optional first
argument, if you so wish.

<!-- !test in named function expression -->

    (var f (lambda tea () (return "T")))

<!-- !test out named function expression -->

    var f = function tea() {
        return 'T';
    };

#### Function declarations

These work much like function expressions above, but require a name.

<!-- !test in function declaration -->

    (function tea () (return "T"))

<!-- !test out function declaration -->

    function tea() {
        return 'T';
    }

### Loops

While-loops (with the `while` macro) take the first argument to be the loop
conditional and the rest to be statements in the block.

<!-- !test in while loop -->

    (var n 10)
    (while (-- n)
     (hello n)
     (hello (- n 1)))

<!-- !test out while loop -->

    var n = 10;
    while (--n) {
        hello(n);
        hello(n - 1);
    }

Do-while-loops similarly: the macro for them is called `dowhile`.

For-loops (with `for`) take their first three arguments to be the initialiser,
condition and update expressions, and the rest to the loop body.

<!-- !test in for loop -->

    (for (var x 0) (< x 10) (++ x)
     (hello n))

<!-- !test out for loop -->

    for (var x = 0; x < 10; ++x) {
        hello(n);
    }

For-in-loops (with `forin`) take the first to be the left part of the loop
header, the second to be the right, and the rest to be body statements.

<!-- !test in for-in loop -->

    (forin (var x) xs
           ((. console log) (get xs x)))

<!-- !test out for-in loop -->

    for (var x in xs) {
        console.log(xs[x]);
    }

You can use an explicit block statements (with the `block` macro) wherever
implicit ones are allowed, if you want to.

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

If you want labeled statements, use `label`.  You can `break` or `continue` to
labels as you'd expect.

<!-- !test in while loop with label -->

    (label x
           (while (-- n)
                  (while (-- n2) (break x))))

<!-- !test out while loop with label -->

    x:
        while (--n) {
            while (--n2) {
                break x;
            }
        }

### Exceptions

The `throw` macro compiles to a throw-statement.

<!-- !test in throw -->

    (throw (new Error))

<!-- !test out throw -->

    throw new Error();

Try-catches are built with `try`.  Its arguments are treated as body
statements, unless they are a list which first element is an identifier `catch`
or `finally`, in which case they are treated as the catch- or finally-clause.

<!-- !test in try-catch -->

    (try (a)
         (b)
         (catch err
                (logError err)
                (f a b))
         (finally ((. console log) "done")))

<!-- !test out try-catch -->

    try {
        a();
        b();
    } catch (err) {
        logError(err);
        f(a, b);
    } finally {
        console.log('done');
    }

Either the catch- or finally- or both clauses need to be present, but they can
appear at any position.  At the end is probably most readable.

## User-defined macros

If you can think of any better way to write any of the above, or wish you could
write something in a way that you can't in core eslisp, check out [how macros
work][11] to learn how to introduce your own.

Even if you don't care about writing your own language features, you might like
to look into what user macros already exist, and if some of them might be
useful to you.

[1]: how-macros-work.markdown
[2]: https://github.com/anko/eslisp/blob/master/doc/how-macros-work.markdown#transform-macros
[3]: https://www.npmjs.com/package/eslisp-camelify
[4]: https://www.npmjs.com/package/eslisp-propertify
[5]: http://dept-info.labri.fr/~strandh/Teaching/PFS/Common/Strandh-Tutorial/indentation.html
[6]: #arithmetic
[7]: #declaration-and-assignment
[8]: #increment-and-decrement
[9]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Assignment_Operators
[10]: https://github.com/anko/eslisp-propertify
[11]: how-macros-work.markdown
