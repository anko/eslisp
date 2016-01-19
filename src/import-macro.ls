# This module deals with transforming data between the form that is passed to
# user macros and returned from them, and the internal compiler AST form used
# otherwise.  Also, deals with inserting macros into compilation environments.

ast-errors = require \./esvalid-partial
{ is-expression } = require \esutils .ast

statementify = require \./es-statementify

# Only used directly by aliases
import-compilerspace-macro = (env, name, func) ->
  env.import-macro name, func

# Only used by transform macros, which run on the initial AST
create-transform-macro = (env, func) ->
  (...args) ->

    result = func.apply env, args

    if typeof! result is \Array
      return result
    else return [ result ]

module.exports = {
  import-compilerspace-macro,
  create-transform-macro
}
