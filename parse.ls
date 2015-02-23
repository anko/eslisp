{ first, map, fold } = require \prelude-ls
es-generate = (require \escodegen).generate _

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

# Takes in an S-expression in the internal format.
# Puts out a corresponding SpiderMonkey AST.
compile = (ast, parent-macro-table) ->

  macro-table = contents : {}, parent : parent-macro-table

  define-macro = (
    [ name, ...function-args ],
    macro-table-for-compiling,
    macro-table-to-add-to
  ) ->

    # To make user-defined macros simpler to write, they encode s-expressions
    # as nested arrays.  This means we have to take their return values and
    # convert them to the internal nested-objects form before compiling.
    to-internal-ast-form = (user-macro-ast-form) ->
      u = user-macro-ast-form
      switch typeof! u
      | \Array  => type : \list contents : u.map to-internal-ast-form
      | \Object =>
        u
        # TODO handle actual objects, not just stuff that's implicitly an atom
      | \String => fallthrough
      | \Number => type : \Literal value : u
      | \Undefined => fallthrough
      | \Null      => null
      | otherwise =>
        throw Error "Unexpected return type #that from macro #{name.text}"

    # Inverse of the above (used when passing values to macros)
    to-macro-ast-form = (compiler-macro-ast-form) ->
      u = compiler-macro-ast-form
      switch u.type
      | \list => u.contents .map to-macro-ast-form
      | \atom => u
      | \string => u.text
      | otherwise => u

    es-ast-macro-fun = compile do
      * type : \list
        contents : [ { type : \atom text : \lambda } ] ++ function-args
      * macro-table-for-compiling

    userspace-macro = do
      let (evaluate = (code) -> eval es-generate (compile code, macro-table))
        eval ("(" + (es-generate es-ast-macro-fun) + ")")
    # need those parentheses to get eval to accept a function expression

    console.log userspace-macro.to-string!

    compilerspace-macro = (compile, ...args) ->

      args = args.map to-macro-ast-form

      userspace-macro-result = userspace-macro.apply null args
      console.log "userspace-macro-result"
      console.log JSON.stringify userspace-macro-result
      internal-ast-form = to-internal-ast-form userspace-macro-result
      console.log "internal-ast-form"
      console.log JSON.stringify internal-ast-form
      compile internal-ast-form

    macro-table-to-add-to.contents[name.text] = compilerspace-macro

    # TODO lots of error checking

    return null

  if ast is null then return null
  switch ast.type
  | \atom =>
    if ast.text.match /\d+(\.\d+)?/ # looks like a number
      type  : \Literal
      value : Number ast.text
      raw   : ast.text
    else
      type : \Identifier
      name : ast.text
  | \string =>
    type : \Literal
    value : ast.text
    raw : '"' + ast.text + '"'
  | \list =>
    if ast.contents.length is 0 then type : \EmptyStatement
    else
      { contents:[ head, ...rest ]:contents } = ast

      if not head?
        return null

      else if head.type is \atom and head.text is \macro
        define-macro rest, macro-table, macro-table.parent
        return null

      else if find-macro macro-table, head.text
        args = rest
          ..unshift (compile _, macro-table)
        that.apply null, args

      else

        # TODO could do a compile-time check here for whether the callee is
        # of a sensible type (e.g. error when calling a string)

        type : \CallExpression
        callee : compile head, macro-table
        arguments : rest .map -> compile it, macro-table

  | otherwise => ast

is-expression = ->
  it.type.match /Expression$/ or it.type in <[ Literal Identifier ]>

statementify = (es-ast-node) ->
  if es-ast-node |> is-expression
    type : \ExpressionStatement expression : es-ast-node
  else es-ast-node

root-macro-table = do

  chained-binary-expr = (type, operator) ->
    macro = (compile, ...args) ->
      | args.length is 1 => compile args.0
      | args.length is 2
        type : type
        operator : operator
        left  : compile args.0
        right : compile args.1
      | arguments.length > 2
        [ head, ...rest ] = args
        macro do
          compile
          macro compile, compile head
          macro.apply null ([ compile ] ++ rest)
      | otherwise =>
        throw Error "binary expression macro `#operator` unexpectedly called \
                     with no arguments"

  unary-expr = (operator) ->
    (compile, arg) ->
      type : \UnaryExpression
      operator : operator
      prefix : true
      argument : compile arg

  n-ary-expr = (operator) ->
    n-ary = chained-binary-expr \BinaryExpression operator
    unary = unary-expr operator
    (compile, ...args) ->
      ( switch args.length | 0 => null
                           | 1 => unary
                           | _ => n-ary
      ).apply null arguments

  update-expression = (operator, {type}) ->
    unless operator in <[ ++ -- ]>
      throw Error "Illegal update expression operator #operator"
    is-prefix = ( type is \prefix )
    (compile, ...arg) ->
      if arg.length isnt 1
        throw Error "Expected `++` expression to get exactly 1 argument but \
                     got #{arguments.length}"
      type : \UpdateExpression
      operator : operator
      prefix : is-prefix
      argument : compile arg.0

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

    \and : chained-binary-expr \LogicalExpression \&&
    \or  : chained-binary-expr \LogicalExpression \||
    \not : unary-expr \!

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

    \array : (compile, ...elements) ->
      type : \ArrayExpression
      elements : elements.map compile

    \= : do
      declaration = (compile, ...args) ->
        if args.length isnt 2
          throw Error "Expected variable declaration to get 2 arguments, \
                       but got #{arguments.length}."
        type : \VariableDeclaration
        kind : "var"
        declarations : [
          type : \VariableDeclarator
          id : compile args.0
          init : compile args.1
        ]

      declaration

    \if : do
      if-statement = (compile, test, consequent, alternate) ->
        type : \IfStatement
        test       : compile test
        consequent : statementify compile consequent
        alternate  : statementify compile alternate
      if-statement

    \?: : do
      ternary = (compile, test, consequent, alternate) ->
        type : \ConditionalExpression
        test       : compile test
        consequent : compile consequent
        alternate  : compile alternate
      ternary

    \break : ->
      type : \BreakStatement
      label : null # TODO?
    \continue : ->
      type : \ContinueStatement
      label : null # TODO?

    \return : (compile, arg) ->
      type : \ReturnStatement
      argument : compile arg

    \. : do
      dot = (compile, ...args)->
        | args.length is 1  # dotting just one thing makes no sense?
          compile first arg # eh whatever, just return it
        | args.length is 2
          type : \MemberExpression
          computed : false
          object   : compile args.0
          property : compile args.1
        | args.length > 2
          [ ...initial, last ] = args
          dot do
            dot.apply null, ([ compile ] ++ initial.map compile)
            compile last
      dot

    \lambda : do
      compile-function-body = (compile, nodes) ->

        nodes = nodes
          .map compile
          .filter (isnt null) # in case of macros

        last-node = nodes.pop!
        # Automatically return last node if it's an expression
        nodes.push if is-expression last-node
          type : \ReturnStatement
          argument : last-node
        else last-node

        type : \BlockStatement
        body : nodes.map statementify

      lambda = (compile, params, ...body) ->
        type : \FunctionExpression
        id : null
        params : params.contents.map compile
        body : compile-function-body compile, body
      lambda

    \quote : do
      quote-one = (ast) ->
        switch ast.type
        | \atom =>
          if ast.text.match /\d+(\.\d+)?/ # looks like a number
            type  : \Literal
            value : Number ast.text
            raw   : ast.text
          else
            type : \ObjectExpression
            properties :
              * type  : \Property
                key   : { type : \Literal value : \type }
                value : { type : \Literal value : \atom }
              * type  : \Property
                key   : { type : \Literal value : \text }
                value : { type : \Literal value : ast.text }
        | \string =>
          type : \Literal
          value : ast.text
          raw : '"' + ast.text + '"'
        | \list =>
          type : \ArrayExpression
          elements : ast.contents.map quote-one

      quote = (compile, ...args) ->
        type : \ArrayExpression
        elements : args.map quote-one

    \quasiquote : do

      qq-body = (compile, ast) ->

        recurse-on = (ast-list) ->
          type : \ArrayExpression
          elements : ast-list.contents |> map qq-body compile, _ |> fold (++), []

        switch ast.type
        | \list =>
          [head, ...rest] = ast.contents
          if not head? # empty list
            [ quote [] ]
          else if head.type is \atom
            switch head.text
            | \unquote =>
              if rest.length isnt 1
                throw Error "Expected 1 argument to unquote but got
                             #{rest.length}"
              [ compile rest.0 ]
            | \unquoteSplicing =>
              if rest.length isnt 1
                throw Error "Expected 1 argument to unquoteSplicing but got
                             #{rest.length}"
              console.log "unquotesplicing"
              console.log JSON.stringify rest.0
              compile rest.0
            | otherwise => [ recurse-on ast ]
          else # head wasn't an atom
            [ recurse-on ast ]
        | otherwise => [ quote-one ast ]

      qq = (compile, ...args) ->
        console.log "args"
        console.log JSON.stringify args
        compileds = args
        |> map qq-body compile, _
        |> ->
          console.log "after qqbody"
          console.log JSON.stringify it
          it
        |> map ->
          if typeof! it is \Array
            type : \ArrayExpression
            elements : it
          else it

        console.log "compileds"
        console.log JSON.stringify compileds

        r =
          type : \CallExpression
          callee :
            type : \MemberExpression
            object :
              type : \MemberExpression
              object :
                type : \Identifier
                name : \Array
              property :
                type : \Identifier
                name : \prototype
            property :
              type : \Identifer
              name : \concat
          arguments : compileds
        console.log "final"
        console.log JSON.stringify r
        r


module.exports = (ast) ->
  statements = ast.contents
  type : \Program
  body : statements
    .map -> compile it, root-macro-table
    .filter (isnt null) # macro definitions emit nothing, hence this
    .map statementify
