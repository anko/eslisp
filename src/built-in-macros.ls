{ map, zip, concat-map, fold1 } = require \prelude-ls
{ is-expression } = require \esutils .ast
statementify = require \./es-statementify
{
  import-compilerspace-macro
  multiple-statements
} = require \./import-macro

chained-binary-expr = (type, operator) ->
  macro = ->
    | &length is 0 =>
      throw Error "binary expression macro `#operator` unexpectedly called \
                   with no arguments"
    | &length is 1 => @compile &0
    | &length is 2 =>
      type : type
      operator : operator
      left  : @compile &0
      right : @compile &1
    | otherwise =>
      [ head, ...rest ] = &
      macro.call do
        this
        macro.call this, @compile head
        macro.apply this, rest

  ->
    if &length is 1
      throw Error "Chained binary expression `#operator` unexpectedly called \
                   with 1 argument"
    else
      macro ...

unary-expr = (operator) -> (arg) ->
  type : \UnaryExpression
  operator : operator
  prefix : true
  argument : @compile arg

n-ary-expr = (operator) ->
  n-ary = chained-binary-expr \BinaryExpression operator
  unary = unary-expr operator
  ->
    switch &length
      | 0 => throw Error "#operator requires at least 1 argument"
      | 1 => unary ...
      | _ => n-ary ...

update-expression = (operator, {type}) ->
  unless operator in <[ ++ -- ]>
    throw Error "Illegal update expression operator #operator"
  is-prefix = type is \prefix
  (value) ->
    if &length isnt 1
      throw Error "Expected `++` expression to get exactly 1 argument but \
                   got #{&length}"
    type : \UpdateExpression
    operator : operator
    prefix : is-prefix
    argument : @compile value

quote = (item) ->
  | &length > 1 =>
    throw Error "Too many arguments to quote; \
                 expected 1 but got #{&length}"
  | item => @compile-to-quote item
  | otherwise =>
    # Compile as if empty list
    @compile-to-quote do
      { type : \list values : [] location : "returned from macro" }

optionally-implicit-block-statement = ({compile, compile-many}, body) ->
  if body.length is 1
    body-compiled = compile body.0
    if body-compiled.type is \BlockStatement then return body-compiled

  type : \BlockStatement
  body : compile-many body .map statementify

# Here's a helper that extracts the common parts to macros for
# FunctionExpressions and FunctionDeclarations since they're so similar.
function-type = (type) -> (params, ...rest) ->
  # The first optional atom argument gives the id that should be attached to
  # the function expression.  The next argument is the function's argument
  # list.  All further arguments are statements for the body.

  var id

  if params.type is \atom
    id = type : \Identifier name : params.value
    params = rest.shift!.values .map @compile
  else
    # Let's assume it's a list then
    id = null
    params = params.values.map @compile

  type : type
  id : id
  params : params
  body : optionally-implicit-block-statement this, rest

is-atom = (node, name) ->
  type-ok  = node.type is \atom
  value-ok = if name then (node.value is name) else true

  type-ok and value-ok

is-list = (node) -> node.type is \list

maybe-unwrap-quote = (node) ->
  if (is-list node) and (is-atom node.values.0, \quote)
    computed : false
    node : node.values.1
  else
    computed : true
    node : node

# For some final coercion after compilation, when building the ESTree AST.
coerce-property = (node, computed) ->
  # This should be explicitly overridden and unconditional. Helps with
  # minifiers and other things.
  | node.type is \Literal =>
    node : node
    computed : false
  | otherwise => { node, computed }

contents =
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

  \=    : chained-binary-expr \AssignmentExpression \=
  \+=   : chained-binary-expr \AssignmentExpression \+=
  \-=   : chained-binary-expr \AssignmentExpression \-=
  \*=   : chained-binary-expr \AssignmentExpression \*=
  \/=   : chained-binary-expr \AssignmentExpression \/=
  \%=   : chained-binary-expr \AssignmentExpression \%=
  \>>=  : chained-binary-expr \AssignmentExpression \>>=
  \<<=  : chained-binary-expr \AssignmentExpression \<<=
  \>>>= : chained-binary-expr \AssignmentExpression \>>>=
  \&=   : chained-binary-expr \AssignmentExpression \&=
  \|=   : chained-binary-expr \AssignmentExpression \|=
  \^=   : chained-binary-expr \AssignmentExpression \^=

  \seq : (...expressions) ->
    type : \SequenceExpression
    expressions : expressions .map @compile

  \array : (...elements) ->
    type : \ArrayExpression
    elements : elements.map @compile

  \object : do
    check-list = (list, i) ->
      | list? and list.type is \list => list.values
      | otherwise => throw Error "Expected property #i to be a list"

    infer-name = (prefix, name, computed) ->
      if computed
        prefix
      else if typeof name.type is \Literal
        "#prefix #{name.value}"
      else
        "#prefix #{name.name}"

    compile-get-set = (i, type, [name, params, ...body]) ->
      if not name?
        throw Error "Expected #{type}ter in property #i to have a name"

      {node, computed} = maybe-unwrap-quote name

      unless computed or node.type is \atom
        throw Error "Expected name of #{type}ter in property #i to be a quoted
          atom or an expression"

      {node : name, computed} = coerce-property (@compile node), computed
      kind = infer-name "#{type}ter", name, computed

      unless params?.type is \list
        throw Error "Expected #{kind} in property #i to have a parameter list"

      params .= values

      # Catch this error here, to return a more sensible, helpful error message
      # than merely an InvalidAstError referencing property names from the
      # stringifier itself.
      if type is \get
        if params.length isnt 0
          throw Error "Expected #{kind} in property #i to have no parameters"
      else # type is \set
        if params.length isnt 1
          throw Error "Expected #{kind} in property #i to have exactly one \
                       parameter"
        param = params.0
        if param.type isnt \atom
          throw Error "Expected parameter for #{kind} in property #i to be an \
                       identifier"
        params = [
          type : \Identifier
          name : param.value
        ]

      type : \Property
      kind : type
      key : name
      # The initial check doesn't cover the compiled case.
      computed : computed
      value :
        type : \FunctionExpression
        id : null
        params : params
        body : optionally-implicit-block-statement this, body
        expression : false

    compile-method = (i, [name, params, ...body]) ->
      if not name?
        throw Error "Expected method in property #i to have a name"

      {node, computed} = maybe-unwrap-quote name

      unless computed or node.type is \atom
        throw Error "Expected name of method in property #i to be a quoted atom
          or an expression"

      {node : name, computed} = coerce-property (@compile node), computed
      method = infer-name 'method', name, computed

      if not params? or params.type isnt \list
        throw Error "Expected #method in property #i to have a parameter \
                     list"

      params = for param, j in params.values
        if param.type isnt \atom
          throw Error "Expected parameter #j for #method in property #i to be \
                       an identifier"
        type : \Identifier
        name : param.value

      type : \Property
      kind : \init
      method : true
      computed : computed
      key : name
      value :
        type : \FunctionExpression
        id : null
        params : params
        body : optionally-implicit-block-statement this, body
        expression : false

    compile-list = (i, args) ->
      | args.length is 0 =>
        throw Error "Expected at least two arguments in property #i"

      | args.length is 1 =>
        node = args.0

        if node.type isnt \list
          throw Error "Expected name in property #i to be a quoted atom"

        [type, node] = node.values

        unless type `is-atom` \quote and node.type is \atom
          throw Error "Expected name in property #i to be a quoted atom"

        type : \Property
        kind : \init
        key :
          type : \Identifier
          name : node.value
        value :
          type : \Identifier
          name : node.value
        shorthand : true

      | args.length is 2 =>
        {node, computed} = maybe-unwrap-quote args.0

        if not computed and node.type isnt \atom
          throw Error "Expected name of property #i to be an expression or
            quoted atom"

        {node : key, computed} = coerce-property (@compile node), computed

        type : \Property
        kind : \init
        computed : computed
        key : key
        value : @compile args.1

      # Check this before compilation and macro resolution to ensure that
      # neither can affect this, but that it can be avoided in the edge case if
      # needed with `(id get)` or `(id set)`, where `(macro id (lambda (x) x))`.
      | args.0 `is-atom` \get or args.0 `is-atom` \set =>
        compile-get-set.call this, i, args.0.value, args[1 til]

      # Reserve this for future generator use.
      | args.0.type `is-atom` \* =>
        throw Error "Unexpected generator method in property #i"

      | otherwise => compile-method.call this, i, args

    ->
      type : \ObjectExpression
      properties : for args, i in arguments
        compile-list.call this, i, (check-list args, i)

  \var : (name, value) ->
    if &length > 2
      throw Error "Expected variable declaration to get 1 or 2 arguments, \
                   but got #{&length}."
    type : \VariableDeclaration
    kind : "var"
    declarations : [
      type : \VariableDeclarator
      id : @compile name
      init : if value then @compile value else null
    ]

  \block : (...statements) ->
    type : \BlockStatement
    body : @compile-many statements .map statementify

  \switch : (discriminant, ...cases) ->
    type : \SwitchStatement
    discriminant : @compile discriminant
    cases : cases.map (.values)
      .map ([t, ...c]) ~>
        type       : \SwitchCase
        test       : do
          t = @compile t
          if t.type is \Identifier and t.name is \default
            null # emit "default:" switchcase label
          else t
        consequent : @compile-many c .map statementify

  \if : (test, consequent, alternate) ->
    type : \IfStatement
    test       : @compile test
    consequent : statementify @compile consequent
    alternate :
      if alternate then statementify @compile that
      else null

  \?: : (test, consequent, alternate) ->
    type : \ConditionalExpression
    test       : @compile test
    consequent : @compile consequent
    alternate  : @compile alternate

  \while : (test, ...body) ->
    type : \WhileStatement
    test : @compile test
    body : optionally-implicit-block-statement this, body

  \dowhile : (test, ...body) ->
    type : \DoWhileStatement
    test : @compile test
    body : optionally-implicit-block-statement this, body

  \for : (init, test, update, ...body) ->
    type : \ForStatement
    init : @compile init
    test : @compile test
    update : @compile update
    body : optionally-implicit-block-statement this, body

  \forin : (left, right, ...body) ->
    type : \ForInStatement
    left : @compile left
    right : @compile right
    body : optionally-implicit-block-statement this, body

  \break : (arg) ->
    type : \BreakStatement
    label : if arg then @compile arg else null

  \continue : (arg) ->
    type : \ContinueStatement
    label : if arg then @compile arg else null

  \label : (label, body) ->
    if &length not in [ 1 2 ]
      throw Error "Expected `label` macro to get 1 or 2 arguments, but got \
                   #{&length}"
    body = if body then statementify @compile body
                   else type : \EmptyStatement

    type  : \LabeledStatement
    label : @compile label
    body  : body

  \return : (arg) ->
    type : \ReturnStatement
    argument : @compile arg

  \. : do

    join-as-member-expression = (host-node, prop-node) ->

      host = @compile host-node

      { node : prop-node, computed } = maybe-unwrap-quote prop-node

      if not computed and prop-node.type isnt \atom
        throw Error "Expected quoted name of property getter to be an atom"

      prop = @compile prop-node

      type : \MemberExpression
      computed : computed
      object   : host
      property : prop

    ->
      | &length is 0 => throw Error "dot called with no arguments"
      | &length is 1 => @compile &0
      | otherwise =>
        [].slice.call arguments
        |> fold1 join-as-member-expression.bind @

  \lambda : function-type \FunctionExpression

  \function : function-type \FunctionDeclaration

  \new : (newTarget, ...newArgs) ->
    if not newTarget? then throw Error "No target for `new`"
    # `newArgs` can be empty though

    type : \NewExpression
    callee : @compile newTarget
    arguments : newArgs .map @compile

  \debugger : ->
    if &length
      throw Error "Expected no arguments to `debugger` statement"
    type : \DebuggerStatement

  \throw : (item) ->
    if &length isnt 1
      throw Error "Expected 1 argument to `throws`; got #{&length}"

    type : \ThrowStatement
    argument : @compile item

  \regex : (expr, flags) ->
    if &length not in [ 1 2 ]
      throw Error "Expected 1 or 2 arguments to `regex`; got #{&length}"

    type : \Literal
    value : new RegExp expr.value, flags?value

  \try : do
    is-part = (thing, clause-name) ->
      thing.type is \list and thing.values.0 `is-atom` clause-name

    (...args) ->
      catch-part = null
      finally-part = null
      others = []

      args.for-each ->
        if it `is-part` \catch
          if catch-part then throw Error "Duplicate `catch` clause"
          catch-part := it.values.slice 1
        else if it `is-part` \finally
          if finally-part then throw Error "Duplicate `finally` clause"
          finally-part := it.values.slice 1
        else
          others.push it

      catch-clause = if catch-part
        type : \CatchClause
        param : @compile catch-part.shift!
        body : optionally-implicit-block-statement this, catch-part
      else null

      finally-clause = if finally-part
        optionally-implicit-block-statement this, finally-part
      else null

      type : \TryStatement
      block :
        type : \BlockStatement
        body : @compile-many others .map statementify
      handler : catch-clause
      finalizer : finally-clause

  \macro : ->
    compile-as-macro = (es-ast) ~>

      # This hack around require makes loading macros from relative paths work.
      #
      # It was guided by LiveScript's implementation
      # https://github.com/gkz/LiveScript/blob/a7525ce6fe7d4906f5d401edf94f15fe5a6b471e/src/node.ls#L10-L18
      # which originally derives from the Coco language.
      #
      # The gist of it is to use the main module's `require` method, such that
      # the current working directory is the root relative to which packages
      # are searched.

      {main} = require
      dirname = "."
      main
        ..paths = main.constructor._node-module-paths process.cwd!
        ..filename = dirname

      root-require = main.require.bind main

      let require = root-require
        eval "(#{@compile-to-js es-ast})"

    switch &length
    | 1 =>
      form = &0
      switch
      | form.type is \atom

        # Mask any macro of that name in the current scope

        import-compilerspace-macro this, form.value, null

      | otherwise

        # Attempt to compile the argument, hopefully into an object,
        # define macros from its keys

        es-ast = @compile form

        result = compile-as-macro es-ast

        switch typeof! result
        | \Object =>
          for k, v of result
            import-compilerspace-macro this, k, v
        | \Null, \Undefined => # do nothing
        | otherwise =>
          throw Error "Invalid macro source #that (expected to get an Object, \
                       or a name argument and a Function)"
    | 2 =>
      [ name, form ] = &

      switch
      | form.type is \atom

        name = name.value
        target-name = form.value

        alias-target-macro = @find-macro target-name

        if not alias-target-macro
          throw Error "Macro alias target `#target-name` is not defined"

        import-compilerspace-macro this, name, alias-target-macro

      | form.type is \list

        userspace-macro = form |> @compile |> compile-as-macro

        name .= value
        import-compilerspace-macro this, name, userspace-macro

    | otherwise =>
      throw Error "Bad number of arguments to macro constructor \
                   (expected 1 or 2; got #that)"
    return null

  \quote : quote

  \quasiquote : do

    # Compile an AST node which is part of the body of a quasiquote.  This
    # means we have to resolve lists which first atom is `unquote` or
    # `unquote-splicing` into either an array of values or an identifier to
    # an array of values.

    qq-body = (ast) ->

      recurse-on = (ast-list) ~>
        ast-list.values
        |> map qq-body.bind this
        |> generate-concat

      unquote = ~>
        if &length isnt 1
          throw Error "Expected 1 argument to unquote but got #{rest.length}"

        # Unquoting should compile to just the thing separated with an array
        # wrapper.
        [ @compile it ]

      unquote-splicing = ~>
        if &length isnt 1
          throw Error "Expected 1 argument to unquoteSplicing but got
                       #{rest.length}"

        # Splicing should leave it without the array wrapper so concat
        # splices it into the array it's contained in.

        type : \MemberExpression
        computed : false
        object : @compile it
        property :
          type : \Identifier
          name : \values

      switch
      | ast.type is \list
        [head, ...rest] = ast.values
        switch
        | not head?
          # quote an empty list
          [ quote.call this, {
            type : \list
            values : []
            location : "returned from macro"
          } ]
        | head `is-atom` \unquote => unquote ...rest
        | head `is-atom` \unquote-splicing => unquote-splicing ...rest
        | _   => [ recurse-on ast ]

      | _ => [ quote.call this, ast ]

    generate-concat = (concattable-things) ->

      # Each quasiquote-body resolution produces SpiderMonkey AST compiled
      # values, but if there are many of them, it'll produce an array.  We'll
      # convert these into ArrayExpressions so the results are effectively
      # still compiled values.

      concattable-things
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
      |> ->
        type : \ObjectExpression
        properties : [
          * type : \Property
            kind : \init
            key :
              type : \Identifier
              name : \type
            value :
              type : \Literal
              value : \list
              raw : "\"list\""
          * type : \Property
            kind : \init
            key :
              type : \Identifier
              name : \values
            value :
              type : \CallExpression
              callee :
                type : \MemberExpression
                object :
                  type : \MemberExpression
                  object   : type : \Identifier name : \Array
                  property : type : \Identifier name : \prototype
                property   : type : \Identifier name : \concat
              arguments : it
        ]
    qq = (arg) ->
      if &length > 1
        throw Error "Too many arguments to quasiquote (`); \
                     expected 1, got #{&length}"

      if arg.type is \list and arg.values.length
        if arg.values.0 `is-atom` \unquote
          rest = arg.values.slice 1 .0
          @compile rest

        else
          arg.values
          |> map qq-body.call this, _
          |> generate-concat

      else quote.call this, arg # act like regular quote

module.exports =
  parent : null
  contents : contents
