{ Transform } = require \stream

macros =
  BinaryExpression : (operator, left, right) ->
    console.log "operator" operator
    { type : \BinaryExpression operator, left, right }
  LiteralNum : (n) ->
    { type : \Literal value : Number n }

module.exports = parse = (tokens) ->

  parse-next = ->
    tree = []
    while token = tokens.shift!
      console.log token
      switch token.name
      | \L_PAREN  => tree.push parse-next!
      | \R_PAREN  =>
        if macros[tree.0]
          console.log "Applying to #{tree.0}"
          return that.apply null, tree.slice 1
        else throw Error "Undefined macro '#{tree.0}'"
      | otherwise => tree.push token.content
    return tree

  parse-next!0
