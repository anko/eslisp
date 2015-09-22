{ concat-map }   = require \prelude-ls
root-macro-table = require \./built-in-macros
statementify     = require \./es-statementify
environment      = require \./env

module.exports = (ast) ->

  # Create an extra node on the "linked list" of macro tables so multiple runs
  # of the compiler have somewhere to put any new macro definitions, without
  # changing the underlying root macro table.  This guards multiple compiler
  # invocations from accidentally influencing each other.
  root-env = environment root-macro-table

  statements = ast.content

  type : \Program
  body : statements
         |> concat-map (.compile root-env)
         |> (.filter (isnt null)) # because macro definitions emit null
         |> (.map statementify)
