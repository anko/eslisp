# Checks if an ESTree AST is valid, but prunes errors about where nodes are
# positioned in the tree.

require! \esvalid

module.exports = ->
  return null if it is null
  it
  |> esvalid.errors
  |> -> it.filter ->
    # Disregard errors to do with where things are allowed to appear.  Eslisp
    # compiles stuff incrementally and takes care that the context makes sense.
    it.message not in [
      "given AST node should be of type Program"
      "ReturnStatement must be nested within a FunctionExpression or FunctionDeclaration node"
      "BreakStatement must have an IterationStatement or SwitchStatement as an ancestor"
      "ContinueStatement must have an IterationStatement as an ancestor"
    ]
  |> -> | it.length => it
        | _         => null
