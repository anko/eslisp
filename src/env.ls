{ concat-map } = require \prelude-ls
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

  find-macro : find-macro

module.exports = env
