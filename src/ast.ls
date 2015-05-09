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

    compile-to-function = (function-args) ->

      # function-args is the forms that go after the `lambda` keyword, so
      # including parameter list and function body.

      es-ast = list ([ atom \lambda ] ++ function-args)
        .compile macro-table

      userspace-function = do
        let (evaluate = -> it |> (.compile macro-table) |> es-generate |> eval)
          eval "(#{es-generate es-ast})"
          # Yep, we need those parentheses, to get `eval` to accept a function
          # expression.

    import-macro = (name, func, macro-table) ->

      # macro function form → internal compiler-form
      #
      # To make user-defined macros simpler to write, they may return just
      # plain JS values, which we'll read back here as AST nodes.  This makes
      # macros easier to write and a little more tolerant of silliness.
      convert = (ast) ->
        if ast instanceof [ string, atom ] then return ast
        if ast instanceof list then return list ast.contents!map convert
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

      compilerspace-macro = (compile, ...args) ->
        args .= map ->
          if it instanceof list
            it.contents!
          else it
        userspace-macro-result = func.apply null, args
        internal-ast-form = convert userspace-macro-result
        if internal-ast-form is null
          return null
        else
          return compile internal-ast-form

      macro-table.parent.contents[name] = compilerspace-macro
    define-macro = ([ name, ...function-args ], macro-table) !->

      # TODO error checking

      name .= text!

      userspace-macro = compile-to-function function-args, macro-table

      import-macro name, userspace-macro, macro-table

    macros-block = (body, macro-table) ->

      # Compile the body as if it were a function with no parameters
      body-as-function = compile-to-function do
        ([list [] ] ++ body) # prepend empty parameter list
        macro-table

      # Run it
      ret = body-as-function!

      # Check that return type is object

      if typeof! ret isnt \Object
        throw Error "Non-object return from `macros`! (got `#{typeof! ret}`)"
      # Check that object keys make sense (no whitespace)
      # Check that object values are functions
      # Import object as new macros
      for name, func of ret

        # sanity: no space or parens in macro name
        if name.match /[\s()]/ isnt null
          throw Error "`macros` return has illegal characters in return name"
        if typeof func isnt \function
          throw Error """`macros` return object value wasn't a function
                         (got `#{typeof! func}`)"""

        import-macro name, func, macro-table

    return type : \EmptyStatement if @content.length is 0

    [ head, ...rest ] = @content

    return null unless head

    if head instanceof atom
    and head.text! is \macro then
      define-macro rest, macro-table
      return null

    else if head instanceof atom
    and head.text! is \macros then
      macros-block rest, macro-table
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
