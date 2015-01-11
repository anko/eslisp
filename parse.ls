# Takes in an S-expression.
# Puts out a corresponding SpiderMonkey AST.

{ lists-to-obj, compact, Obj : compact : obj-compact } = require \prelude-ls

quote = (node) ->
  switch node.type
  | \atom   => node.text
  | \string => "\"#{node.text.replace /\"/g, "\\\""}\""
  | \list   => node.contents .map quote

unquote = (node) ->
  switch node.type
  | \atom   => # TODO handle number-looking atoms specially?
    type : \Identifier
    name : node.text
  | \string =>
    type : \Literal
    value : node.text
    raw : quote node
  | \list =>
    type : \ArrayExpression
    elements : node.contents.map quote

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
        rest.map ->
          | it.type is \list =>
            [ head, rest ] = it.contents
            if head.type is \atom and head.text is \unquote
              rest.map unquote
            else
              quote it
          | otherwise => quote it
      | \macro => # macro definition
        [ name, params, body ] = rest
        console.log name, params, body

        if name.type isnt \atom
          throw Error "Macro name has bad type #{name.type} (expected atom)"
        if params.type isnt \list
          throw Error "Macro param list has bad type #{name.type} (expected list)"
        if body.type isnt \list
          throw Error "Macro body has bad type #{name.type} (expected list)"

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

  switch typeof! ret
  | \Array    => compact ret
  | \Object   => obj-compact ret
  | otherwise => ret

module.exports = (ast) ->
  type : \Program
  body : compile ast, { parent : null contents : {} }
