# This module deals with transforming data between the form that is passed to
# user macros and returned from them, and the internal compiler AST form used
# otherwise.  Also, deals with inserting macros into compilation environments.

ast-errors = require \./esvalid-partial
{ is-expression } = require \esutils .ast

# This is only used to let macros return multiple statements, in a way
# detectable as different from other return types with an
# `instanceof`-check.
class multiple-statements
  (...args) ~>
    @statements = args

statementify = require \./es-statementify

# Only used directly by aliases
import-compilerspace-macro = (env, name, func) ->
  env.import-macro name, func

# Only used by transform macros, which run on the initial AST
create-transform-macro = (env, func) ->
  (...args) ->

    result = func.apply env, args

    if result instanceof multiple-statements
      return result.statements
    else return [ result ]

module.exports = {
  import-compilerspace-macro,
  create-transform-macro,
  multiple-statements
}
