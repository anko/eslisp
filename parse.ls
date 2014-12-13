{ Transform } = require \stream
{ lists-to-obj } = require \prelude-ls

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

module.exports = parse = (tokens) ->

  parse-next = ->
    tree = []
    while token = tokens.shift!
      switch token.name
      | \L_PAREN  =>
        tree.push parse-next!
        env := new-env env
      | \R_PAREN  =>
        if find-macro env, tree.0
          console.log "Applying to #{tree.0}"
          env := env.parent || env
          code = that tree.slice 1
          console.log "Macro returned" code
          return code
        else throw Error "Undefined macro '#{tree.0}'"
      | otherwise => tree.push token.content
    return tree

  parse-next!0
