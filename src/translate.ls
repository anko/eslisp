{ first, map, fold, zip, concat-map, unfoldr, reverse } = require \prelude-ls
{ atom, list, string } = require \./ast
uuid = require \uuid .v4
require! \esvalid
{ is-expression } = require \esutils .ast

statementify = (es-ast-node) ->
  if es-ast-node |> is-expression
    type : \ExpressionStatement expression : es-ast-node
  else es-ast-node

root-macro-table = do

  chained-binary-expr = (type, operator) ->
    macro = (env, ...args) ->
      | args.length is 1 => env.compile args.0
      | args.length is 2
        type : type
        operator : operator
        left  : env.compile args.0
        right : env.compile args.1
      | arguments.length > 2
        [ head, ...rest ] = args
        macro do
          env
          macro env, env.compile head
          macro.apply null ([ env ] ++ rest)
      | otherwise =>
        throw Error "binary expression macro `#operator` unexpectedly called \
                     with no arguments"

  unary-expr = (operator) ->
    ({ compile }, arg) ->
      type : \UnaryExpression
      operator : operator
      prefix : true
      argument : compile arg

  n-ary-expr = (operator) ->
    n-ary = chained-binary-expr \BinaryExpression operator
    unary = unary-expr operator
    ({compile}, ...args) ->
      ( switch args.length | 0 => null
                           | 1 => unary
                           | _ => n-ary
      ).apply null arguments

  update-expression = (operator, {type}) ->
    unless operator in <[ ++ -- ]>
      throw Error "Illegal update expression operator #operator"
    is-prefix = ( type is \prefix )
    ({ compile }, ...arg) ->
      if arg.length isnt 1
        throw Error "Expected `++` expression to get exactly 1 argument but \
                     got #{arguments.length}"
      type : \UpdateExpression
      operator : operator
      prefix : is-prefix
      argument : compile arg.0

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

  import-macro = (env, name, func) ->

    # The macro table of the current environment is what should be used when
    # the macro is called.  This preserves lexical scoping.

    # To expand a bit more on that:  This fixes situations where a macro, which
    # the now-defined macro uses, is redefined later.  The redefinition should
    # not affect this macro's behaviour, so we have to hold on to a copy of the
    # environment as it was when we defined this.

    flattened-macro-table = env.macro-table
      |> unfoldr -> [ it, it.parent ] if it # get chain of nested macro tables
      |> map (.contents)                    # get their contents
      |> reverse                            # they're backwards, so reverse
      |> fold (<<<), {}                     # import each from oldest to newest
      |> -> parent : null contents : it     # wrap as expected

    # Emulate the usual compile functions, but using the flattened macro table
    # from this environment.
    compile = ->
      if it.compile?
        it.compile flattened-macro-table, env.macro-table
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

          errors = esvalid.errors sm-ast
            .filter (.message isnt "given AST node should be of type Program")
                     # no neater way of detecting that currently...

          throw Error errors.0 if errors.length

          sm-ast

    # If the import target macro table is available, import the macro to that.
    # Otherwise, import it to the usual table.

    (env.import-target-macro-table || env.macro-table)
      .parent.contents[name] = compilerspace-macro

  quote = ->
    if arguments.length > 1
      throw Error "Too many arguments to quote; \
                   expected 1 but got #{arguments.length}"
    if it then it.as-sm!
    else list!as-sm! # empty list

  parent : null
  contents :
    \+ : n-ary-expr \+
    \- : n-ary-expr \-
    \* : chained-binary-expr \BinaryExpression \*
    \/ : chained-binary-expr \BinaryExpression \/
    \% : chained-binary-expr \BinaryExpression \%

    \++  : update-expression \++ type : \prefix # Synonym for below
    \++_ : update-expression \++ type : \prefix
    \_++ : update-expression \++ type : \suffix
    \--  : update-expression \-- type : \prefix # Synonym for below
    \--_ : update-expression \-- type : \prefix
    \_-- : update-expression \-- type : \suffix

    \&& : chained-binary-expr \LogicalExpression \&&
    \|| : chained-binary-expr \LogicalExpression \||
    \!  : unary-expr \!

    \< : chained-binary-expr \BinaryExpression \<
    \> : chained-binary-expr \BinaryExpression \>
    \<= : chained-binary-expr \BinaryExpression \<=
    \>= : chained-binary-expr \BinaryExpression \>=

    \delete : unary-expr \delete
    \typeof : unary-expr \typeof
    \void   : unary-expr \void
    \instanceof : chained-binary-expr \BinaryExpression \instanceof
    \in : chained-binary-expr \BinaryExpression \in

    \& : chained-binary-expr \BinaryExpression \&
    \| : chained-binary-expr \BinaryExpression \|
    \^ : chained-binary-expr \BinaryExpression \^
    \>>  : chained-binary-expr \BinaryExpression \>>
    \<<  : chained-binary-expr \BinaryExpression \<<
    \>>> : chained-binary-expr \BinaryExpression \>>>
    \~ : unary-expr \~

    \==  : chained-binary-expr \BinaryExpression \==
    \!=  : chained-binary-expr \BinaryExpression \!=
    \=== : chained-binary-expr \BinaryExpression \===
    \!== : chained-binary-expr \BinaryExpression \!==

    \:=   : chained-binary-expr \AssignmentExpression \=
    \+=   : chained-binary-expr \AssignmentExpression \+=
    \-=   : chained-binary-expr \AssignmentExpression \-=
    \*=   : chained-binary-expr \AssignmentExpression \*=
    \%=   : chained-binary-expr \AssignmentExpression \%=
    \>>=  : chained-binary-expr \AssignmentExpression \>>=
    \<<=  : chained-binary-expr \AssignmentExpression \<<=
    \>>>= : chained-binary-expr \AssignmentExpression \>>>=
    \&=   : chained-binary-expr \AssignmentExpression \&=
    \|=   : chained-binary-expr \AssignmentExpression \|=
    \^=   : chained-binary-expr \AssignmentExpression \^=

    \seq : ({ compile }, ...expressions) ->
      type : \SequenceExpression
      expressions : expressions .map compile

    \array : ({ compile }, ...elements) ->
      type : \ArrayExpression
      elements : elements.map compile

    \object : ({ compile }, ...args) ->

      if args.length % 2 isnt 0
        throw Error "Expected even number of arguments to object macro, but \
                     got #{args.length}"

      keys-values = do # [ [k1, v1], [k2, v2] , ... ]
        keys = [] ; values = []
        args.for-each (a, i) -> (if i % 2 then values else keys).push a
        zip keys, values

      type : \ObjectExpression
      properties :
        keys-values.map ([k, v]) ->
          type : \Property kind : \init
          value : compile v
          key : compile k

    \= : do
      declaration = ({compile}, ...args) ->
        if args.length > 2
          throw Error "Expected variable declaration to get 1 or 2 arguments, \
                       but got #{arguments.length}."
        type : \VariableDeclaration
        kind : "var"
        declarations : [
          type : \VariableDeclarator
          id : compile args.0
          init : if args.1 then compile args.1 else null
        ]

      declaration

    \switch : ({compile, compile-many}, discriminant, ...cases) ->
      type : \SwitchStatement
      discriminant : compile discriminant
      cases : cases .map (.contents!)
        .map ([t, ...c]) ->
          type       : \SwitchCase
          test       : do
            t = compile t
            if t.type is \Identifier and t.name is \default
              null # emit "default:" switchcase label
            else t
          consequent : compile-many c .map statementify

    \if : ({compile, compile-many}, test, consequent, alternate) ->
      type : \IfStatement
      test       : compile test
      consequent :
        type : \BlockStatement
        body : compile-many consequent.contents! .map statementify
      alternate :
        if alternate
          type : \BlockStatement
          body : compile-many alternate.contents! .map statementify
        else null

    \?: : ({compile}, test, consequent, alternate) ->
      type : \ConditionalExpression
      test       : compile test
      consequent : compile consequent
      alternate  : compile alternate

    \while : ({compile, compile-many}, test, ...body) ->
      type : \WhileStatement
      test : compile test
      body :
        type : \BlockStatement
        body : compile-many body .map statementify

    \dowhile : ({compile, compile-many}, test, ...body) ->
      type : \DoWhileStatement
      test : compile test
      body :
        type : \BlockStatement
        body : compile-many body .map statementify

    \for : ({compile, compile-many}, init, test, update, ...body) ->
      type : \ForStatement
      init : compile init
      test : compile test
      update : compile update
      body :
        type : \BlockStatement
        body : compile-many body .map statementify

    \forin : ({compile, compile-many}, left, right, ...body) ->
      type : \ForInStatement
      left : compile left
      right : compile right
      body :
        type : \BlockStatement
        body : compile-many body .map statementify

    \break : ->
      type : \BreakStatement
      label : null # TODO?
    \continue : ->
      type : \ContinueStatement
      label : null # TODO?

    \return : ({compile}, arg) ->
      type : \ReturnStatement
      argument : compile arg

    \. : do

      is-computed-property = (ast-node) ->
        switch ast-node.type
        | \MemberExpression =>
          is-computed-property ast-node.object
        | \Identifier => false
        | otherwise => true

      dot = ({compile}:env, ...args) ->
        | args.length is 1 => compile args.0
        | args.length is 2
          property-compiled = compile args.1
          type : \MemberExpression
          computed : is-computed-property property-compiled
          object   : compile args.0
          property : property-compiled
        | arguments.length > 2
          [ ...initial, last ] = args
          dot do
            env
            dot.apply null ([ env ] ++ initial)
            dot env, compile last
        | otherwise =>
          throw Error "dot called with no arguments"

    \get : do
      get = ({compile}:env, ...args) ->
        | args.length is 1 => compile args.0
        | args.length is 2
          property-compiled = compile args.1
          type : \MemberExpression
          computed : true # `get` is always computed
          object   : compile args.0
          property : property-compiled
        | arguments.length > 2
          [ ...initial, last ] = args
          get do
            env
            get.apply null ([ env ] ++ initial)
            get env, compile last
        | otherwise =>
          throw Error "dot called with no arguments"


    \function : do
      compile-function-body = (compile-many, nodes) ->

        nodes = compile-many nodes

        last-node = nodes.pop!
        # Automatically return last node if it's an expression
        nodes.push if is-expression last-node
          type : \ReturnStatement
          argument : last-node
        else last-node

        type : \BlockStatement
        body : nodes.map statementify

      func = ({compile, compile-many}, params, ...body) ->
        type : \FunctionExpression
        id : null
        params : params.contents!map compile
        body :
          type : \BlockStatement
          body : compile-many body .map statementify
      func

    \new : ({compile}, ...args) ->
      [ newTarget, ...newArgs ] = args

      if not newTarget? then throw Error "No target for `new`"
      # `newArgs` can be empty though

      type : \NewExpression
      callee : compile newTarget
      arguments : newArgs .map compile

    \debugger : (_, ...args) ->
      if args.length
        throw Error "Expected no arguments to `debugger` statement"
      type : \DebuggerStatement

    \throw : ({compile}, ...args) ->

      if args.length isnt 1
        throw Error "Expected 1 argument to `throws`; got #{args.length}"

      type : \ThrowStatement
      argument : compile args.0

    \regex : ({compile}, ...args) ->

      if args.length isnt 1
        throw Error "Expected 1 argument to `regex`; got #{args.length}"

      type : \Literal
      value : new RegExp args.0.text!

    \try : ({compile, compile-many}, ...args) ->

      block = args.shift!
      unless block instanceof list
        throw Error "Expected `try` block (first argument) to be a list"

      # The `catch`- and `finally`-clauses can come in either order

      clause-a = args.shift!
      clause-b = args.shift!

      if args.length
        throw Error "Unexpected fourth argument to `try` \
                     (expected between 1 and 3)"

      unless clause-a
        throw Error "`try` has no catch- or finally-block \
                     (expected either or both)"

      read-clause = (clause, options={}) ->
        return unless clause
        contents-a = clause.contents!
        type-a = contents-a.shift!
        unless type-a instanceof atom and type-a.text! in <[ catch finally ]>
          throw Error "First clause of `try` not labelled `catch` or `finally`"
        switch type-a.text!
        | \catch
          if options.deny-catch then throw Error "Duplicate `catch` clause"

          type : \catch
          pattern : compile contents-a.shift!
          body :
            type : \BlockStatement
            body : compile-many contents-a .map statementify
        | \finally
          if options.deny-finally then throw Error "Duplicate `finally` clause"

          type : \finally
          body :
            type : \BlockStatement
            body : compile-many contents-a .map statementify

      var catch-clause, finally-clause
      a = read-clause clause-a
      switch a?type
      | \catch   => catch-clause   := a
      | \finally => finally-clause := a

      b = read-clause clause-b, switch a.type # disallow same again
                                | \catch   => { +deny-catch }
                                | \finally => { +deny-finally }
      switch b?type
      | \catch   => catch-clause   := b
      | \finally => finally-clause := b

      type : \TryStatement
      block :
        type : \BlockStatement
        body : compile-many block.contents! .map statementify
      handler :
        if catch-clause
          type  : \CatchClause
          param : catch-clause.pattern
          body  : catch-clause.body
        else null
      finalizer : if finally-clause then that.body
                  else null

    \macro : (env, ...args) ->

      compile-as-macro = (es-ast) ->
        # This is deliberately defined in the closure here, so it's in scope
        # during the `eval` and available to the code being compiled.
        let { require } = require.main
          eval "(#{env.compile-to-js es-ast})"

      switch args.length
      | 1 =>
        es-ast = env.compile args.0

        result = compile-as-macro es-ast

        switch typeof! result
        | \Object =>
          for k, v of result
            import-macro env, k, v
        | \Null => fallthrough
        | \Undefined => # do nothing
        | otherwise =>
          throw Error "Invalid macro source #that (expected to get an Object, \
                       or a name argument and a Function)"
      | 2 =>
        [ name, form ] = args

        userspace-macro = form |> env.compile |> compile-as-macro

        name .= text!
        import-macro env, name, userspace-macro

      | otherwise =>
        throw Error "Bad number of arguments to macro constructor \
                     (expected 1 or 2; got #that)"
      return null

    \quote : (_, ...args) -> quote.apply null, args

    \quasiquote : do

      # Compile an AST node which is part of the body of a quasiquote.  This
      # means we have to resolve lists which first atom is `unquote` or
      # `unquote-splicing` into either an array of values or an identifier to
      # an array of values.
      qq-body = (compile, ast) ->

        recurse-on = (ast-list) ->
          type : \ArrayExpression
          elements : ast-list.contents!
                     |> map qq-body compile, _
                     |> fold (++), []

        unquote = ->
          if arguments.length isnt 1
            throw Error "Expected 1 argument to unquote but got #{rest.length}"

          # Unquoting should compile to just the thing separated with an array
          # wrapper.
          [ compile it ]

        unquote-splicing = ->
          if arguments.length isnt 1
            throw Error "Expected 1 argument to unquoteSplicing but got
                         #{rest.length}"

          # Splicing should leave it without the array wrapper so concat
          # splices it into the array it's contained in.
          compile it

        switch
        | ast instanceof list
          [head, ...rest] = ast.contents!
          switch
          | not head? => [ quote list [] ] # empty list
          | head instanceof atom =>
            switch head.text!
            | \unquote          => unquote         .apply null rest
            | \unquote-splicing => unquote-splicing.apply null rest
            | _ => [ recurse-on ast ]
          | _   => [ recurse-on ast ]

        | _ => [ quote ast ]

      generate-concat = (concattable-things) ->
        type : \CallExpression
        callee :
          type : \MemberExpression
          object :
            type : \MemberExpression
            object   : type : \Identifier name : \Array
            property : type : \Identifier name : \prototype
          property   : type : \Identifier name : \concat
        arguments : concattable-things

      qq = ({compile}, ...args) ->

        if args.length > 1
          throw Error "Too many arguments to quasiquote (`); \
                       expected 1, got #{args.length}"
        arg = args.0

        if arg instanceof list and arg.contents!length

          first-arg = arg.contents!0

          if first-arg instanceof atom and first-arg.text! is \unquote
            rest = arg.contents!slice 1 .0
            compile rest

          else
            concattable-args = arg.contents!

              # Each argument is resolved by quasiquote's rules.
              |> map qq-body compile, _

              # Each quasiquote-body resolution produces SpiderMonkey AST
              # compiled values, but if there are many of them, it'll produce
              # an array.  We'll convert these into ArrayExpressions so the
              # results are effectively still compiled values.
              |> map ->
                if typeof! it is \Array
                  type : \ArrayExpression elements : it
                else it

            # Now each should be an array (or a literal that was
            # `unquote-splicing`ed) so they can be assumed to be good for
            # `Array::concat`.

            # We then construct a call to Array::concat with each of the now
            # quasiquote-resolved and compiled things as arguments.  That makes
            # this macro produce a concatenation of the quasiquote-resolved
            # arguments.

            generate-concat concattable-args

        else quote arg # act like regular quote

module.exports = (ast) ->

  macro-table = contents : {}, parent : root-macro-table
  statements = ast.content

  type : \Program
  body : statements
    |> concat-map (.compile macro-table)
    |> (.filter (isnt null)) # macro definitions emit nothing, hence this
    |> (.map statementify)
