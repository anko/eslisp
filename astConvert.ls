# This module converts between the different formats that an AST can take:
#
# - SM (SpiderMonkey) format, used as input to escodegen
# - Internal format, used inside this compiler only
# - Macro format, used when passing an AST to a macro function

looks-like-number = (atom-text) ->
  atom-text.match /\d+(\.\d+)?/

# internal compiler-form → SpiderMonkey AST form
internal-to-sm = (ast) ->
  switch ast.type
  | \atom =>
    if ast.text |> looks-like-number
      type  : \Literal
      value : Number ast.text
      raw   : ast.text
    else
      type : \ObjectExpression
      properties :
        * type  : \Property
          key   : { type : \Literal value : \type }
          value : { type : \Literal value : \atom }
        * type  : \Property
          key   : { type : \Literal value : \text }
          value : { type : \Literal value : ast.text }
  | \string =>
    type : \Literal
    value : ast.text
    raw : '"' + ast.text + '"'
  | \list =>
    type : \ArrayExpression
    elements : ast.contents.map internal-to-sm

# macro function form → internal compiler-form
#
# To make user-defined macros simpler to write, they encode s-expressions
# as nested arrays.  This means we have to take their return values and
# convert them to the internal nested-objects form before compiling.
macro-to-internal = (ast) ->
  switch typeof! ast
  # Arrays represent lists
  | \Array  => type : \list contents : ast.map macro-to-internal
  # Objects represent atoms
  | \Object => ast
  | \String => fallthrough
  | \Number => type : \Literal value : ast
  # Undefined and null represent nothing
  | \Undefined => fallthrough
  | \Null      => null
  # Everything else is an error
  | otherwise =>
    throw Error "Unexpected return type #that"

# internal compiler-form → macro function form
#
# Inverse of the above (used when passing values to macros)
internal-to-macro = (ast) ->
  switch ast.type
  | \list =>     ast.contents .map internal-to-macro
  | \string =>   ast.text
  | \atom =>     fallthrough
  | otherwise => ast

module.exports = {
  internal-to-sm,
  macro-to-internal,
  internal-to-macro
}
