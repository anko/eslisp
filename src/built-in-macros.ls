{ map, zip, concat-map } = require \prelude-ls
{ is-expression } = require \esutils .ast
statementify = require \./es-statementify
{
  import-compilerspace-macro
  multiple-statements
} = require \./import-macro
Module = require \module
require! \path

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

compile-unless-empty-list = (compile, ast) ->
  if ast.type isnt \list
    throw Error "Unexpected argument AST; expected list"
  if ast.values.length then compile ast
                       else null

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

  \object : (...args) ->

    { compile } = env = this
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
    init : compile-unless-empty-list @compile, init
    test : compile-unless-empty-list @compile, test
    update : compile-unless-empty-list @compile, update
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

    is-computed-property = (ast-node) ->
      switch ast-node.type
      | \Identifier => false
      | otherwise => true

    dot = (...args) ->

      { compile } = env = this

      switch
      | args.length is 1 => compile args.0
      | args.length is 2
        property-compiled = compile args.1
        type : \MemberExpression
        computed : is-computed-property property-compiled
        object   : compile args.0
        property : property-compiled
      | arguments.length > 2
        [ ...initial, last ] = args
        dot.call do
          env
          dot.apply env, initial
          dot.call env, compile last
      | otherwise =>
        throw Error "dot called with no arguments"

  \get : do
    get = (...args) ->

      { compile } = env = this

      switch
      | args.length is 1 => compile args.0
      | args.length is 2
        property-compiled = compile args.1
        type : \MemberExpression
        computed : true # `get` is always computed
        object   : compile args.0
        property : property-compiled
      | arguments.length > 2
        [ ...initial, last ] = args
        get.call do
          env
          get.apply env, initial
          get.call env, compile last
      | otherwise =>
        throw Error "dot called with no arguments"


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
      if not (thing.type is \list) then return false
      first = thing.values.0
      (first.type is \atom) && (first.value is clause-name)

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
    env = this

    compile-as-macro = (es-ast) ->

      [ lookup-filename, displayed-filename ] = do ->
        # If we know we are compiling a particular file, have `require` look up
        # relative paths relative to that file.  This makes macro `require`s
        # with relative paths work as expected.
        | env.filename =>
          p = path.resolve that
          [ p, p ]
        # If we are compiling without a filename (that is, code from stdin or
        # interactively in a REPL), have `require` resolve relative to the
        # current working directory.
        | otherwise => [ process.cwd!, null ]

      new-module = new Module "eslisp-internal:#displayed-filename" null
        ..paths    = Module._node-module-paths lookup-filename
        ..filename = displayed-filename
      require-substitute = new-module.require.bind new-module

      let require = require-substitute
        eval "(#{env.compile-to-js es-ast})"

    switch &length
    | 1 =>
      form = &0
      switch
      | form.type is \atom

        # Mask any macro of that name in the current scope

        import-compilerspace-macro env, form.value, null

      | otherwise

        # Attempt to compile the argument, hopefully into an object,
        # define macros from its keys

        es-ast = env.compile form

        result = compile-as-macro es-ast

        switch typeof! result
        | \Object =>
          for k, v of result
            import-compilerspace-macro env, k, v
        | \Null => fallthrough
        | \Undefined => # do nothing
        | otherwise =>
          throw Error "Invalid macro source #that (expected to get an Object, \
                       or a name argument and a Function)"
    | 2 =>
      [ name, form ] = &

      switch
      | form.type is \atom

        name = name.value
        target-name = form.value

        alias-target-macro = env.find-macro target-name

        if not alias-target-macro
          throw Error "Macro alias target `#target-name` is not defined"

        import-compilerspace-macro env, name, alias-target-macro

      | form.type is \list

        userspace-macro = form |> env.compile |> compile-as-macro

        name .= value
        import-compilerspace-macro env, name, userspace-macro

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
    qq-body = (env, ast) ->

      recurse-on = (ast-list) ->
        ast-list.values
        |> map qq-body env, _
        |> generate-concat

      unquote = ->
        if arguments.length isnt 1
          throw Error "Expected 1 argument to unquote but got #{rest.length}"

        # Unquoting should compile to just the thing separated with an array
        # wrapper.
        [ env.compile it ]

      unquote-splicing = ->
        if arguments.length isnt 1
          throw Error "Expected 1 argument to unquoteSplicing but got
                       #{rest.length}"

        # Splicing should leave it without the array wrapper so concat
        # splices it into the array it's contained in.

        type : \MemberExpression
        computed : false
        object :
          env.compile it
        property :
          type : \Identifier
          name : \values

      switch
      | ast.type is \list
        [head, ...rest] = ast.values
        switch
        | not head?
          # quote an empty list
          [ quote.call env, {
            type : \list
            values : []
            location :"returned from macro"
          } ]
        | head.type is \atom =>
          switch head.value
          | \unquote          => unquote         .apply null rest
          | \unquote-splicing => unquote-splicing.apply null rest
          | _ => [ recurse-on ast ]
        | _   => [ recurse-on ast ]

      | _ => [ quote.call env, ast ]

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

      env = this

      if &length > 1
        throw Error "Too many arguments to quasiquote (`); \
                     expected 1, got #{&length}"

      if arg.type is \list and arg.values.length

        first-arg = arg.values.0

        if first-arg.type is \atom and first-arg.value is \unquote
          rest = arg.values.slice 1 .0
          env.compile rest

        else
          arg.values
          |> map qq-body env, _
          |> generate-concat

      else quote.call env, arg # act like regular quote

module.exports =
  parent : null
  contents : contents
