{ concat-map }   = require \prelude-ls
root-macro-table = require \./built-in-macros
statementify     = require \./es-statementify

module.exports = (ast) ->

  macro-table = contents : {}, parent : root-macro-table
  statements = ast.content

  type : \Program
  body : statements
    |> concat-map (.compile macro-table)
    |> (.filter (isnt null)) # macro definitions emit nothing, hence this
    |> (.map statementify)
