# Turns an internal AST form into an estree object with reference to the given
# root environment.  Throws error unless the resulting estree AST is valid.

{ concat-map, reject }   = require \prelude-ls
root-macro-table = require \./built-in-macros
statementify     = require \./es-statementify
environment      = require \./env
compile          = require \./compile

{ create-transform-macro } = require \./import-macro

{ errors } = require \esvalid

module.exports = (root-env, ast, options={}) ->

  transform-macros = (options.transform-macros || []) .map (func) ->
    isolated-env = environment root-macro-table
    create-transform-macro isolated-env, func

  statements = ast

  transform-macros .for-each (macro) ->
    statements := (macro.apply null, statements)
      .filter (isnt null)

  program-ast =
    type : \Program
    body : statements
           |> concat-map -> compile root-env, it
           |> (.filter (isnt null)) # because macro definitions emit null
           |> (.map statementify)

  err = errors program-ast |> reject ({node}) ->
    # These are valid ES6 nodes, and their errors need to be ignored. See
    # https://github.com/estools/esvalid/issues/7.
    | node.type is \Property =>
      node.computed and node.key?.type not in <[Identifier Literal]>
    | otherwise => false

  if err.length
    first-error = err.0
    throw first-error
  else
    return program-ast
