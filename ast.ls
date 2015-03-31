{ obj-to-lists, zip } = require \prelude-ls
es-generate = (require \escodegen).generate _

looks-like-number = (atom-text) ->
  atom-text.match /\d+(\.\d+)?/

class string
  (@content-text) ~>

  text : ->
    return @content-text if not it?
    @content-text := it

  as-sm : ->
    type : \Literal
    value : @content-text
    raw : "\"#{@content-text}\""
  as-macro-form : -> @content-text

  compile : ->
    type : \Literal
    value : @content-text
    raw : "\"#{@content-text}\""

class atom
  (@content-text) ~>

  text : ->
    return @content-text if not it?
    @content-text := it

  as-sm : ->
    if @content-text |> looks-like-number
      type  : \Literal
      value : Number @content-text
      raw   : @content-text
    else
      type : \CallExpression
      callee :
        type : \Identifier
        name : \atom
      arguments : [ { type : \Literal, value : @content-text, raw : "\"#{@content-text}\"" } ]
  as-macro-form : -> { type : \atom, text : @content-text }

  compile : ->
    if @content-text |> looks-like-number
      type  : \Literal
      value : Number @content-text
      raw   : @content-text
    else
      type : \Identifier
      name : @content-text

class list
  (@content=[]) ~>

  contents : ->
    return @content if not it?
    @content := it

  as-sm : ->
    type : \CallExpression
    callee :
      type : \Identifier
      name : \list
    arguments : [
        type : \ArrayExpression elements : @content.map (.as-sm!)
    ]
  as-macro-form : -> @content.map (.as-macro-form!)

  compile : (parent-macro-table) ->

    macro-table = contents : {}, parent : parent-macro-table

    # Recursively search a macro table and its parents for a macro with a given
    # name.  Returns `null` if unsuccessful; a macro representing the function
    # if successful.
    find-macro = (macro-table, name) ->
      switch macro-table.contents[name]
      | null => null                          # deliberately masks parent; fail
      | undefined =>                          # not defined at this level
        if macro-table.parent
          find-macro macro-table.parent, name # ask parent
        else return null                      # no parent to ask; fail
      | otherwise => that                     # defined at this level; succeed

    define-macro = ([ name, ...function-args ], macro-table) !->

      # TODO error checking

      name .= text!

      es-ast-macro-fun = list ([ atom \lambda ] ++ function-args)
        .compile macro-table

      userspace-macro = do
        let (evaluate = -> it |> (.compile macro-table) |> es-generate |> eval)
          eval "(#{es-generate es-ast-macro-fun})"
          # Yep, we need those parentheses, to get `eval` to accept a function
          # expression.

      # macro function form → internal compiler-form
      #
      # To make user-defined macros simpler to write, they may return just
      # plain JS values, which we'll read back here as AST nodes.  This makes
      # macros easier to write and a little more tolerant of silliness.
      convert = (ast) ->
        if ast instanceof [ string, atom ] then return ast
        if ast instanceof list then return list ast.contents!map convert
        #console.log ast
        switch typeof! ast
        # Arrays represent lists
        | \Array  => list ast.map convert
        # Objects are turned into lists too
        | \Object =>
          [ keys, values ] = obj-to-lists ast
          keys   .= map convert
          values .= map convert
          keys-values = zip keys, values
          list ([ \object ] ++ keys-values)
        | \String => string ast
        | \Number => atom ("" + ast)
        # Undefined and null represent nothing
        | \Undefined => fallthrough
        | \Null      => null
        # Everything else is an error
        | otherwise =>
          throw Error "Unexpected return type #that"

      console.log userspace-macro.to-string!

      compilerspace-macro = (compile, ...args) ->
        args .= map ->
          if it instanceof list
            it.contents!
          else it
        userspace-macro-result = userspace-macro.apply null, args
        console.log JSON.stringify userspace-macro-result
        internal-ast-form = convert userspace-macro-result
        if internal-ast-form is null
          return null
        else
          return compile internal-ast-form

      macro-table.parent.contents[name] = compilerspace-macro

    return type : \EmptyStatement if @content.length is 0

    [ head, ...rest ] = @content

    return null unless head

    if head instanceof atom
    and head.text! is \macro then
      define-macro rest, macro-table
      return null

    else if head instanceof atom
    and find-macro macro-table, head.text! then
      args = rest
        ..unshift ->
          if it.compile?
            it.compile macro-table
          else it
      return that.apply null, rest

    else
      # TODO compile-time check if callee has sensible type
      type : \CallExpression
      callee : head.compile macro-table
      arguments : rest.map (.compile macro-table)

module.exports = { atom, string, list }
