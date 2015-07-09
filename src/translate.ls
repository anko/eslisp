{ map, zip, concat-map } = require \prelude-ls
{ atom, list, string } = require \./ast
{ is-expression } = require \esutils .ast
{ import-macro, import-capmacro, multiple-statements } = require \./import-macro
root-macro-table = require \./built-in-macros

statementify = (es-ast-node) ->
  if es-ast-node |> is-expression
    type : \ExpressionStatement expression : es-ast-node
  else es-ast-node

module.exports = (ast) ->

  macro-table = contents : {}, parent : root-macro-table
  statements = ast.content

  type : \Program
  body : statements
    |> concat-map (.compile macro-table)
    |> (.filter (isnt null)) # macro definitions emit nothing, hence this
    |> (.map statementify)
