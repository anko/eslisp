# Comparison of eslisp to other JS-lisps

Here's an overview of other compile-to-JS lisps and how they compare to eslisp.
I'll go in rough order of decreasing similarity.

## Independent JS lisp implementations

[**Jisp**][1] is the most similar existing project. It has implemented macros
slightly differently in the details, and is more opinionated about how code
should be written; everything is an expression, sometimes at the cost of a
one-to-one language mapping.  It is currently not actively maintained.

[**Sibilant**][2] also emphasises staying close to JavaScript semantics, but
unlike eslisp, it accepts extensive syntactic sugar and its macros (though
featureful) are cumbersome to write.

[**LispyScript**][3] adds syntactic sugar quite aggressively.  Its "macros"
are really just substitution templates: they can't do computation, which allows
only extremely simple uses.

## Subsets of other lisps in JS

[**wisp**][4] is a [Clojure][5] subset, inheriting its syntax and many ideas,
but is friendlier to JavaScript.  It is more mature and featureful than eslisp.
However, its syntax inherits some Clojure-isms that translate awkwardly to JS
and its macros compile to an internal representation, so they can't be defined
in separate modules.

[**Ralph**][6] is a [Dylan][7] subset.  It compiles to JavaScript and has a
quasiquoting macro system, but it again has lots some syntax that doesn't
translate obviously into JS.  Allows macros to be defined in separate modules.
Currently not actively maintained.

## Compilers hosted on other lisps

[**ClojureScript**][8] is a heavy approach; a full [Clojure][9] compiler
targeting JavaScript.  Unlike eslisp, it requires the [JVM][10] and totally
overrides JS' semantics.  (The non-JVM [self-hosted implementation][11] does
not yet support macros at the time of writing.)

[**Parenscript**][12] similarly requires a Common Lisp compiler.  It uses CL
idioms, but is implemented instead as a CL library, allowing it to make a
little more effort than ClojureScript to produce readable JavaScript output.

## Lisp interpreters in JS

[**SLip**][13], [**Javathcript**][14], [**Fargo**][15] (and many others) are
interpreters; they work on internal code representations and so have limited
interoperability with other JavaScript.

[1]: http://jisp.io/
[2]: http://sibilantjs.info/
[3]: http://lispyscript.com/
[4]: https://github.com/Gozala/wisp
[5]: http://clojure.org/
[6]: https://github.com/turbolent/ralph
[7]: http://en.wikipedia.org/wiki/Dylan_(programming_language)
[8]: https://github.com/clojure/clojurescript
[9]: http://clojure.org/
[10]: http://en.wikipedia.org/wiki/Java_virtual_machine
[11]: https://github.com/swannodette/cljs-bootstrap
[12]: https://common-lisp.net/project/parenscript/
[13]: http://lisperator.net/slip/
[14]: http://kybernetikos.github.io/Javathcript/
[15]: https://github.com/jcoglan/fargo
