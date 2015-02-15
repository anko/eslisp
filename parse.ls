# Takes in an S-expression.
# Puts out a corresponding SpiderMonkey AST.

{ lists-to-obj, compact, Obj : compact : obj-compact } = require \prelude-ls
full-compile = (require \escodegen).generate _

quote = (node) ->
  node
  /*
  switch node.type
  | \atom   => node.text
  | \string => "\"#{node.text.replace /\"/g, "\\\""}\""
  | \list   => node.contents .map quote
  */

# Returns a function that takes an object parameter. That object-parameter
# should be used to bind the free variables to values, so the function returns
# a version of the code with the appropriate values compiled in.
quasiquote-list = (list) ->

  # Keep everything as usual, but keep note of unbound variables.

  # Each free variable is stored as an object with key "name" holding the
  # variable name and key "nodes" holding a reference to an array of references
  # to node objects that should have their contents replaced.
  #
  # TODO Does "JSONpath" exist (analogously to XPATH) for replacing them
  # in-structure rather than with a reference? References are a bit fragile.
  free-variables = []
  list.map

quasiquote = (node) ->
  switch node.type
  | \atom   => fallthrough
  | \string => quote node
  | \list   =>
    [ head, ...rest ] = node.contents
    if head.type is \atom and head.text is \unquote
      rest
    else
      node.contents .map quasiquote

unquote = (node) ->
  switch node.type
  | \atom   =>
    type : \free-variable
    text : node.text
  | \string => fallthrough
  | \list =>
    throw Error "Cannot unquote type `#that` (expected atom)"

find-macro = (macro-table, name) ->
  switch macro-table.contents[name]
  | null => null
  | otherwise =>
    if macro-table.parent
      find-macro macro-table.parent, name
    else return null

compile = (node, parent-macro-table) ->

  macro-table = contents : {}, parent: parent-macro-table

  ret = switch node.type
  | \string => node.text
  | \atom   =>
    if node.text .match /\d+(\.\d+)?/
      Number node.text
    else node.text
  | \free-variable => that # passthrough; macros handle them
  | \list =>
    [ head, ...rest ] = node.contents
    switch head.type
    | \atom =>
      switch head.text
      | \object => # object constructor
        # Parse rest as alternating object keys and values
        unless (rest.length % 2) is 0
          throw Error "Odd number of arguments to `#that`: expected even"
        keys = [] ; values = []
        rest.for-each (x, i) ->
          (if (i % 2) is 0 then keys else values)
            ..push compile x, macro-table
        lists-to-obj keys, values
      | \array => # array constructor
        rest.map compile _, macro-table
      | \quote =>
        rest.map quote
      | \quasiquote =>
        rest.map quasiquote
      | \macro => # macro definition
        [ name, params, body ] = rest

        if name.type isnt \atom
          throw Error "Macro name has bad type #{name.type} (expected atom)"
        if params.type isnt \list
          throw Error "Macro param list has bad type #{name.type} (expected list)"
        if body.type isnt \list
          throw Error "Macro body has bad type #{name.type} (expected list)"

        name   .= text
        params .= contents
        body   .= contents

        console.log "BODY"
        console.log JSON.stringify body
        compiled-body = body .map compile _, macro-table
        console.log "COMPILED"
        console.log JSON.stringify compiled-body

        fun-expr =
          type : \FunctionExpression
          params : params.map ->
            type : \Identifier
            name : it.text
          body : compile body, macro-table

        ast =
          type : \Program
          body : [
            {
              type : \ExpressionStatement
              expression :
                type : \CallExpression
                callee :
                  type : \FunctionExpression
                  params : []
                  body :
                    type : \BlockStatement
                    body : [
                      { type : \ReturnStatement argument : fun-expr }
                    ]
            }
          ]

        #console.log JSON.stringify ast
        code = full-compile ast
        console.log "CODE", code
        #macro-table.contents[name] = eval code

        null
      | otherwise =>
        if find-macro macro-table, head.text
          that do
            rest.map compile _, macro-table
        else
          throw Error "Macro `#{head.text}` not found."
          # TODO compile to funcall
    | \string => fallthrough
    | \list   => throw Error "Unexpected #that at head of list"

  # Compact returned arrays and objects (remove falsey values).  These could be
  # added by no-ops like macro definitions.

  # TODO refactor

  #console.log "RETURNING"
  #console.log ret

  switch typeof! ret
  | \Array    => compact ret
  | \Object   => obj-compact ret
  | otherwise => ret

module.exports = (ast) ->
  type : \Program
  body : compile ast, { parent : null contents : {} }
