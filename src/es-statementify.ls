# Makes an ESTree AST node into an expression, if it's not one already.

{ is-expression } = require \esutils .ast
module.exports = (es-ast-node) ->
  if es-ast-node |> is-expression
    type : \ExpressionStatement expression : es-ast-node
  else es-ast-node
