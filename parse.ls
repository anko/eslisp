{ Transform } = require \stream

base-env =
  parent : null
  macros :
    BinaryExpression : (operator, left, right) ->
      console.log "operator" operator
      { type : \BinaryExpression operator, left, right }
    LiteralNum : (n) ->
      { type : \Literal value : Number n }


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
      console.log token
      switch token.name
      | \L_PAREN  =>
        tree.push parse-next!
        env := new-env env
      | \R_PAREN  =>
        if find-macro env, tree.0
          console.log "Applying to #{tree.0}"
          env := env.parent || env
          return that.apply null, tree.slice 1
        else throw Error "Undefined macro '#{tree.0}'"
      | otherwise => tree.push token.content
    return tree

  parse-next!0
