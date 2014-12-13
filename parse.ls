{ Transform } = require \stream
{ lists-to-obj, map } = require \prelude-ls

base-env =
  parent : null
  macros :
    object : (children) ->
      keys   = []
      values = []
      children.for-each (a, i) ->
        (if i % 2 is 0 then keys else values)
          ..push a
      lists-to-obj keys, values
    number : (children) ->
      if children.length > 1
        throw Error "Number macro received too many arguments (1 expected)"
      return Number children.0
    array : (children) -> children

new-env = (parent) -> { parent, macros:{} }

find-macro = (env, name) ->
  | env.macros[name] => that
  | otherwise =>
    if env.parent
      find-macro env.parent, name
    else null

env = base-env

evaluate = (env, tree) -->
  console.log "Evaluating" tree
  switch typeof! tree
  | \Array =>
    if find-macro env, tree.0
      console.log "Applying to #{tree.0}"
      code = tree.slice 1
             |> map evaluate (new-env env)
             |> that
      console.log "Macro returned" code
      return code
    else throw Error "Undefined macro '#{tree.0}'"
    # TODO compile to fun call
  | _ => return tree

module.exports = parse = (tokens) ->

  parse-next = (options={}) ->
    tree = []
    while token = tokens.shift!
      switch token.name
      | \L_PAREN  => tree.push parse-next!
      | \R_PAREN  => return tree
      | otherwise => tree.push token.content
    return tree

  evaluate env, parse-next!0
  # TODO wrap in implicit `Program` AST-node
