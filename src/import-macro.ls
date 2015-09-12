# This module deals with importing macros into macro tables (which are mappings
# of names to AST-transforming functions).

{ map, fold, concat-map, unfoldr, reverse, each } = require \prelude-ls
{ atom, list, string } = require \./ast
uuid = require \uuid .v4
ast-errors = require \./esvalid-partial
{ is-expression } = require \esutils .ast

statementify = require \./es-statementify

# This is only used to let macros return multiple statements, in a way
# detectable as different from other return types with an
# `instanceof`-check.
class multiple-statements
  (@statements) ~>

# macro function form → internal compiler-form
#
# To make user-defined macros simpler to write, they may return just plain JS
# values, which we'll read back here as AST nodes.  This makes macros easier
# to write and a little more tolerant of silliness.
to-compiler-form = (ast) ->

  # Stuff already in internal compiler form can stay that way.
  if ast instanceof [ string, atom ] then return ast

  # Lists' contents need to be converted, in case they've got
  # non-compiler-form stuff inside them.
  if ast instanceof list then return list ast.contents!map to-compiler-form

  # Multiple-statements just become an array of their contents, but like
  # lists, those contents might need conversion.
  if ast instanceof multiple-statements
    return ast.statements.map to-compiler-form

  # Everything else needs a little more thinking based on their type
  switch typeof! ast

    # Arrays represent lists
    | \Array  => list ast.map to-compiler-form

    # Objects are expected to represent atoms
    | \Object =>
      if ast.atom then atom ("" + ast.atom)
      else throw Error "Macro returned object without `atom` property"

    # Strings become strings as you'd expect
    | \String => string ast

    # Numbers become atoms
    | \Number => atom ("" + ast)

    # Undefined and null represent nothing
    | \Undefined => fallthrough
    | \Null      => null

    # Anything else errors
    | otherwise => throw Error "Unexpected macro return type #that"

to-macro-form = (compiler-form-ast) ->
  c = compiler-form-ast
  switch
  | c instanceof list   => c.contents!map to-macro-form
  | c instanceof string => c.text!
  | c instanceof atom
    if c.is-number! then Number c.text!
    else atom : c.text!
  | otherwise => throw Error "Internal error: Unexpected compiler AST value"

macro-env = (env) ->

  # Create the functions to be exposed for use in a macro's body based on the
  # given compilation environment

  evaluate = ->
    it |> to-compiler-form |> env.compile |> env.compile-to-js |> eval
  multi    = (...args) -> multiple-statements args
  gensym = ->
    if arguments.length
      throw Error "Got #that arguments to `gensym`; expected none."
    atom "$#{uuid!.replace /-/g, \_}"
    # RFC4122 v4 UUIDs are based on random bits.  Hyphens become
    # underscores to make the UUID a valid JS identifier.

  is-expr = -> it |> to-compiler-form |> env.compile |> is-expression

  { evaluate, multi, gensym, is-expr }

find-root = ({parent}:macro-table) -> | parent => find-root that
                                      | _      => macro-table

import-macro = (env, name, func) ->

  root-env = ^^env
    ..macro-table = find-root env.macro-table
    ..import-target-macro-tables =
      (env.import-target-macro-tables || [ env.macro-table ])

  import-capmacro root-env, name, func

flatten-macro-table = (table) ->
  table
  |> unfoldr -> [ it, it.parent ] if it # get chain of nested macro tables
  |> map (.contents)                    # get their contents
  |> reverse                            # they're backwards, so reverse
  |> fold (<<<), {}                     # import each from oldest to newest
  |> -> # wrap as expected
    parent :
      contents : {}
      parent : null
    contents : it

import-capmacro = (env, name, func) ->

  #console.log "importing macro #name"
  #console.log "into" (env.import-target-macro-tables || env.macro-table).parent

  # The macro table of the current environment is what should be used when
  # the macro is called.  This preserves lexical scoping.

  # To expand a bit more on that:  This fixes situations where a macro, which
  # the now-defined macro uses, is redefined later.  The redefinition should
  # not affect this macro's behaviour, so we have to hold on to a copy of the
  # environment as it was when we defined this.

  flattened-macro-table = flatten-macro-table env.macro-table

  clone-array = (.slice 0)

  # Emulate the usual compile functions, but using the flattened macro table
  # from this environment.
  compile = ->
    if it.compile?

      # Use the previously stored macro scope
      table-to-read-from = flattened-macro-table

      # Import macros both into the outer scope...
      tables-to-import-into =
        if env.import-target-macro-tables then clone-array that
        else [ env.macro-table ]

      # ... and the current compilation's scope
      tables-to-import-into
        ..push flattened-macro-table

      it.compile table-to-read-from, tables-to-import-into
    else it
  compile-many = -> it |> concat-map compile |> (.filter (isnt null))

  # Note that the first argument (normally containing the compilation
  # environment) is ignored.  `compile` and `compile-many` inside here refer
  # to the ones that use the flattened macro table.
  compilerspace-macro = (_, ...args) ->
    args .= map to-macro-form
    userspace-macro-result = func.apply (macro-env env), args

    internal-ast-form = to-compiler-form userspace-macro-result

    return switch
    | internal-ast-form is null => null
    | typeof! internal-ast-form is \Array => compile-many internal-ast-form
    | otherwise =>

      sm-ast = compile internal-ast-form

      switch sm-ast
      | null => null # happens if internal-ast-form was only macros
      | otherwise

        errors = ast-errors sm-ast
        if errors
          console.error "AST error at" sm-ast
          throw Error errors.0

        sm-ast

  # If the import target macro table is available, import the macro to that.
  # Otherwise, import it to the usual table.

  import-into = ->
    it.parent.contents[name] = compilerspace-macro

  if env.import-target-macro-tables
    that |> each import-into
  else
    import-into env.macro-table

module.exports = {
  import-macro, import-capmacro, make-multiple-statements : multiple-statements
}
