{ first, map, fold, zip } = require \prelude-ls
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

looks-like-number = (atom-text) ->
  atom-text.match /\d+(\.\d+)?/

# internal compiler-form → SpiderMonkey AST form
compiler-form-to-sm-form = (ast) ->
  switch ast.type
  | \atom =>
    if ast.text |> looks-like-number
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
    elements : ast.contents.map compiler-form-to-sm-form

# macro function form → internal compiler-form
#
# To make user-defined macros simpler to write, they encode s-expressions
# as nested arrays.  This means we have to take their return values and
# convert them to the internal nested-objects form before compiling.
macro-form-to-compiler-form = (ast) ->
  switch typeof! ast
  # Arrays represent lists
  | \Array  => type : \list contents : ast.map macro-form-to-compiler-form
  # Objects represent atoms
  | \Object => ast
  | \String => fallthrough
  | \Number => type : \Literal value : ast
  # Undefined and null represent nothing
  | \Undefined => fallthrough
  | \Null      => null
  # Everything else is an error
  | otherwise =>
    throw Error "Unexpected return type #that"

# internal compiler-form → macro function form
#
# Inverse of the above (used when passing values to macros)
compiler-form-to-macro-form = (ast) ->
  switch ast.type
  | \list => ast.contents .map compiler-form-to-macro-form
  | \atom => ast
  | \string => ast.text
  | otherwise => ast

# Takes in an S-expression in the compiler format.
# Puts out a corresponding SpiderMonkey AST.
compile = (ast, parent-macro-table) ->

  macro-table = contents : {}, parent : parent-macro-table

  define-macro = (
    [ name, ...function-args ],
    macro-table-for-compiling,
    macro-table-to-add-to
  ) ->
    es-ast-macro-fun = compile do
      * type : \list
        contents : [ { type : \atom text : \lambda } ] ++ function-args
      * macro-table-for-compiling

    userspace-macro = do
      let (evaluate = (code) -> eval es-generate (compile code, macro-table))
        eval ("(" + (es-generate es-ast-macro-fun) + ")")
    # need those parentheses to get eval to accept a function expression

    compilerspace-macro = (compile, ...args) ->
      args .= map compiler-form-to-macro-form
      userspace-macro-result = userspace-macro.apply null args
      internal-ast-form = macro-form-to-compiler-form userspace-macro-result
      compile internal-ast-form

    macro-table-to-add-to.contents[name.text] = compilerspace-macro

    # TODO lots of error checking

    return null

  if ast is null then return null
  switch ast.type
  | \atom =>
    if ast.text |> looks-like-number
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

    \object : (compile, ...args) ->

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

      is-computed-property = (ast-node) ->
        switch ast-node.type
        | \MemberExpression =>
          is-computed-property ast-node.object
        | \Identifier => false
        | otherwise => true

      dot = (compile, ...args) ->
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
            compile
            dot.apply null ([ compile ] ++ initial)
            dot compile, compile last
        | otherwise =>
          throw Error "dot called with no arguments"
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
      quote = (compile, ...args) ->
        if args.length > 1
          throw Error "Attempted to quote >1 values, not inside list"
        if args.0
          args.0 |> compiler-form-to-sm-form
        else
          compiler-form-to-sm-form type : \list contents : []

    \quasiquote : do

      # Compile an internal-form AST node which is part of the body of a
      # quasiquote.  This means we have to resolve lists which first atom is
      # unquote or unquoteSplicing into either an array of values or an
      # identifier to the array of values.
      qq-body = (compile, ast) ->
        recurse-on = (ast-list) ->
          type : \ArrayExpression
          elements : ast-list.contents
                     |> map qq-body compile, _
                     |> fold (++), []

        unquote = ->
          # Unquoting a list should compile to whatever the list
          [ compile it ]
        unquote-splicing = ->
          # The returned thing should be an array anyway.
          compile it

        switch ast.type
        | \list =>
          [head, ...rest] = ast.contents
          if not head? then [ quote [] ] # empty list
          else if head.type is \atom
            switch head.text
            | \unquote =>
              if rest.length isnt 1
                throw Error "Expected 1 argument to unquote but got
                             #{rest.length}"
              unquote rest.0
            | \unquote-splicing =>
              if rest.length isnt 1
                throw Error "Expected 1 argument to unquoteSplicing but got
                             #{rest.length}"
              unquote-splicing rest.0
            | otherwise => [ recurse-on ast ]
          else # head wasn't an atom
            [ recurse-on ast ]
        | otherwise => [ compiler-form-to-sm-form ast ]

      qq = (compile, ...args) ->

        # Each argument (in args) is an atom passed to the quasiquote macro.
        if args.length > 1
          throw Error "Attempted to quasiquote >1 values, not inside list"

        arg = args.0

        switch arg.type
        | \list
          concattable-args = arg.contents

            # Each argument is resolved by quasiquote's rules.
            |> map qq-body compile, _

            # Each quasiquote-body resolution produces SpiderMonkey AST compiled
            # values, but if there are many of them, it'll produce an array.
            # We'll convert these into ArrayExpressions so the results are
            # effectively still compiled values.
            |> map ->
              if typeof! it is \Array
                type : \ArrayExpression
                elements : it
              else it

          # Now each should be an array (or a literal that was
          # `unquote-splicing`ed) so they can be assumed to be good for
          # `Array::concat`.

          # We then construct a call to Array::concat with each of the now
          # quasiquote-resolved and compiled things as arguments.  That makes
          # this macro produce a concatenation of the quasiquote-resolved
          # arguments.

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
          arguments : concattable-args
        | otherwise => quote compile, arg

module.exports = (ast) ->
  statements = ast.contents
  type : \Program
  body : statements
    .map -> compile it, root-macro-table
    .filter (isnt null) # macro definitions emit nothing, hence this
    .map statementify
