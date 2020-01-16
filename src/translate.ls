# Turns an internal AST form into an estree object with reference to the given
# root environment.  Throws error unless the resulting estree AST is valid.

{ concat-map }   = require \prelude-ls
root-macro-table = require \./built-in-macros
statementify     = require \./es-statementify
environment      = require \./env
compile          = require \./compile

{ create-transform-macro } = require \./import-macro

{ errors } = require \esvalid

errors-about-nodes-esvalid-understands = do ->
  # Ignore errors about nodes that esvalid can't currently handle.
  (ast) ->
    # This list is gathered from
    # https://github.com/estools/esvalid/blob/2693f0906a3336de05d3325d10f8aa8297211bdb/index.js
    # At time of writing, esvalid version is 1.1.0
    esvalid-supported-node-types = <[
      ArrayExpression AssignmentExpression BinaryExpression BlockStatement
      BreakStatement CallExpression CatchClause ConditionalExpression
      ContinueStatement DebuggerStatement DoWhileStatement EmptyStatement
      ExpressionStatement ForInStatement ForStatement FunctionDeclaration
      FunctionExpression Identifier IfStatement LabeledStatement Literal
      LogicalExpression MemberExpression NewExpression ObjectExpression Program
      ReturnStatement SequenceExpression SwitchCase SwitchStatement ThisExpression
      ThrowStatement TryStatement UnaryExpression UpdateExpression
      VariableDeclaration VariableDeclarator WhileStatement WithStatement
    ]>
    err = errors ast
      .filter (.node.type in esvalid-supported-node-types)

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

  err = errors-about-nodes-esvalid-understands program-ast
  if err.length
    first-error = err.0
    throw first-error
  else
    return program-ast
