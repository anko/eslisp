{ concat-map }   = require \prelude-ls
root-macro-table = require \./built-in-macros
statementify     = require \./es-statementify
environment      = require \./env
{ list }         = require \./ast

{ create-transform-macro } = require \./import-macro

module.exports = (ast, options) ->

  transform-macros = (options.transform-macros || []) .map (func) ->
    isolated-env = environment root-macro-table
    create-transform-macro isolated-env, func

  # Create an extra node on the "linked list" of macro tables so multiple runs
  # of the compiler have somewhere to put any new macro definitions, without
  # changing the underlying root macro table.  This guards multiple compiler
  # invocations from accidentally influencing each other.
  root-env = environment root-macro-table

  statements = ast.content

  transform-macros .for-each (macro) ->
    statements := macro.apply null, statements

  type : \Program
  body : statements
         |> concat-map (.compile root-env)
         |> (.filter (isnt null)) # because macro definitions emit null
         |> (.map statementify)
