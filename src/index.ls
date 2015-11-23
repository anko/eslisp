string-to-ast = require \./parse
ast-to-estree = require \./translate
estree-to-js  = require \escodegen .generate

root-macro-table = require \./built-in-macros
environment = require \./env

to-estree = (root-env, input, options) ->
  input.to-string!
  |> string-to-ast
  |> ast-to-estree root-env, _, transform-macros : options.transform-macros

compile = (root-env, input, options={}) ->
  to-estree.apply null arguments
  |> estree-to-js

make-stateful-compiler = (options={}) ->
  root-env = environment root-macro-table, { filename : options.filename }
  return compile root-env, _, options

compile-once = (input, options={}) ->
  root-env = environment root-macro-table, { filename : options.filename }
  return compile root-env, input, options

compile-with-source-map = (input, options={}) ->

  root-env = environment do
    root-macro-table
    { filename : options.filename }

  escodegen-opts =
    # We definitely do always want to get a return value with both the code and
    # the associated source map at the same time.  Because macros are
    # user-defined, their return values may be non-deterministic, meaning that
    # two *separate* invocations (one for the code and one for the source map)
    # might be out of sync.
    source-map-with-code : true
    # If we know what file this is for, tell the source map that.  If we don't
    # know (the `true` case), escodegen relies on the estree nodes having `loc`
    # properties, which some crazy macro-writer out there might want to make
    # use of.
    source-map : options.filename || true
    # And here's just the input eslisp code, to be embedded in the source map.
    source-content : input.to-string!

  # First we compile the eslisp code to an estree representation
  estree-object = to-estree root-env, input, options
  # then that to the final representations.
  { code : code, map : map-generator } =
    estree-to-js estree-object, escodegen-opts

  return do
    code : code
    map : map-generator.to-string!

module.exports = compile-once
  ..stateful = make-stateful-compiler
  ..with-source-map = compile-with-source-map
