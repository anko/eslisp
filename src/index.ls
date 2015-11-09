string-to-ast = require \./parse
ast-to-estree = require \./translate
estree-to-js  = (require \escodegen).generate _

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

compile-source-map = (input, options={}) ->

  root-env = environment root-macro-table, { filename : options.filename }

  escodegen-opts =
    sourceMap : options.filename || true
    sourceContent : input.to-string!

  to-estree root-env, input, options
  |> (require \escodegen).generate _, escodegen-opts

module.exports = compile-once
  ..stateful = make-stateful-compiler
  ..source-map = compile-source-map
