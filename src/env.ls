{ concat-map, unfoldr, map, reverse, fold } = require \prelude-ls
es-generate = require \escodegen .generate _

# Recursively search a macro table and its parents for a macro with a given
# name.  Returns `null` if unsuccessful; a macro representing the function if
# successful.
find-macro = (macro-table, name) ->
  switch macro-table.contents[name]
  | null => null                          # deliberately masks parent; fail
  | undefined =>                          # not defined at this level
    if macro-table.parent
      find-macro macro-table.parent, name # ask parent
    else return null                      # no parent to ask; fail
  | otherwise => that                     # defined at this level; succeed

flatten-macro-table = (table) ->
  table
  |> unfoldr -> [ it, it.parent ] if it # get chain of nested macro tables
  |> map (.contents)                    # get their contents
  |> reverse                            # they're backwards, so reverse
  |> fold (<<<), {}                     # import each from oldest to newest
  |> -> # wrap as expected
    parent :
      contents : it
      parent : null
    contents : {}

clone-array = (.slice 0)

class env

  (root-table, import-target-macro-tables) ~>

    @macro-table = contents : {} parent : root-table
    @root-table = root-table


    # The import-target-macro-tables argument is for the situation when a macro
    # returns another macro.  In such a case, the returned macro should be
    # added to the tables specified (the scope the macro that created it was
    # in, as well as the scope of other statements during that compile) not to
    # the table representing the scope of the outer macro's contents.
    #
    # If that's confusing, take a few deep breaths and read it again.  Welcome
    # to the blissful land of Lisp, where everything is recursive somehow.
    @import-target-macro-tables = import-target-macro-tables

  compile : ~> # compile to SpiderMonkey AST
    if it.compile?
      it.compile @
    else it

  compile-many : ~> it |> concat-map @compile |> (.filter (isnt null))

  compile-to-js : -> es-generate it

  derive : ~> env @macro-table, @import-target-macro-tables

  derive-flattened : ~>

    # This method creates a derived environment with its macro table
    # "flattened" to keep a safe local copy of the current compilation
    # environment.  This preserves lexical scoping.

    # To expand a bit more on that:  This fixes situations where a macro, which
    # the now-defined macro uses, is redefined later.  The redefinition should
    # not affect this macro's behaviour, so we have to hold on to a copy of the
    # environment as it was when we defined this.

    flattened-macro-table = flatten-macro-table @macro-table

    # Use the previously stored macro scope
    table-to-read-from = flattened-macro-table

    # Import macros both into the outer scope...
    tables-to-import-into =
      if @import-target-macro-tables then clone-array that
      else [ @macro-table ]

    # ... and the current compilation's scope
    tables-to-import-into
      ..push flattened-macro-table

    env table-to-read-from, tables-to-import-into

  find-macro : find-macro

module.exports = env
