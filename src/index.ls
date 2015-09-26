string-to-ast = require \./parse
ast-to-estree = require \./translate
estree-to-js  = (require \escodegen).generate _

root-macro-table = require \./built-in-macros
environment = require \./env

compile = (root-env, input, options={}) ->

  input .= to-string!

  # Ignore first line if it starts with a shebang
  if input.match /^(#!.*\n)/ then input .= slice that.1.length

  "(#input\n)" # Implicit list of everything (trailing \n terminates comments)
  |> string-to-ast
  |> ast-to-estree root-env, _, transform-macros : options.transform-macros
  |> estree-to-js


make-stateful-compiler = (options={}) ->
  root-env = environment root-macro-table
  return compile root-env, _, options

compile-once = (input, options={}) ->
  root-env = environment root-macro-table
  return compile root-env, input, options

module.exports = compile-once
  ..stateful = make-stateful-compiler
