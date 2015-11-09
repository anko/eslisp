{ multiple-statements } = require \./import-macro

looks-like-positive-number = (atom-text) ->
  atom-text.match /^\d+(\.\d+)?$/
looks-like-negative-number = (atom-text) ->
  atom-text.match /^-\d+(\.\d+)?$/

string-to-estree = (env, { value }:ast) ->
  type  : \Literal
  value : value
  raw   : "\"#{value}\""
  loc   : ast.location

string-to-self-producer = ->
  type : \ObjectExpression
  properties : [
    * type : \Property
      kind : \init
      key :
        type : \Identifier
        name : \type
      value :
        type : \Literal
        value : \string
        raw : "\"string\""
    * type : \Property
      kind : \init
      key :
        type : \Identifier
        name : \value
      value :
        type : \Literal
        value : it
        raw : "\"#{it}\""
  ]

atom-to-estree = (env, { value : name }:ast) ->

  lit = ~>
    type : \Literal value : it, raw : name
    loc : ast.location

  switch name
  | \this  => type : \ThisExpression
  | \null  => lit null
  | \true  => lit true
  | \false => lit false
  | otherwise switch
    | looks-like-positive-number name
      type  : \Literal
      value : Number name
      raw   : name
      loc   : ast.location
    | looks-like-negative-number name
      type     : \UnaryExpression
      operator : \-
      prefix   : true
      argument : lit Number name.slice 1 # trim leading minus
    | otherwise
      type : \Identifier
      name : name
      loc  : ast.location

atom-to-self-producer = ->
  type : \ObjectExpression
  properties : [
    * type : \Property
      kind : \init
      key :
        type : \Identifier
        name : \type
      value :
        type : \Literal
        value : \atom
        raw : "\"atom\""
    * type : \Property
      kind : \init
      key :
        type : \Identifier
        name : \value
      value :
        type : \Literal
        value : it
        raw : "\"#{it}\""
  ]

list-to-self-producer = (env, { values }) ->
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
        type : \ArrayExpression
        elements : values.map (ast-to-self-producer env, _)
  ]

list-to-estree = (env, { values }:ast, options={}) ->

  return null if values.length is 0

  [ head, ...rest ] = values

  return null unless head

  local-env = env.derive!

  r = if head.type is \atom
  and local-env.find-macro head.value

    # Invoke the found macro

    #console.log "invoking macro `#{head.value}`"
    macro-return = that.apply local-env, rest
    #console.log "output from `#{head.value}`"
    #console.log macro-return

    switch typeof! macro-return
    | \Null      => fallthrough
    | \Undefined => null
    | \Object =>

      if macro-return instanceof multiple-statements
        macro-return.statements.for-each ->
          switch typeof! it
          | \Object => # that's OK
          | otherwise =>
            throw Error "Unexpected `#that` value received in multi-return"
        macro-return.statements.map (ast-to-estree env, _)

      else if macro-return.type in <[ atom list string ]>
        ast-to-estree env, macro-return

      else
        macro-return

    | otherwise =>
      throw Error "Unexpected macro return type #that"

  else

    # Compile to a function call

    # If location known, save the filename in it too
    ast.location?source = env.filename

    # TODO compile-time check if callee has sensible type
    type : \CallExpression
    callee : ast-to-estree env, head
    arguments : rest.map (ast-to-estree env, _)
    loc : ast.location

  return r

ast-to-estree = (env, ast, options) ->
  switch ast.type
  | \atom   => atom-to-estree  .apply null arguments
  | \string => string-to-estree.apply null arguments
  | \list   => list-to-estree  .apply null arguments
  | otherwise => ast

ast-to-self-producer = (env, ast) ->
  switch ast.type
  | \atom   => atom-to-self-producer ast.value
  | \string => string-to-self-producer ast.value
  | \list   => list-to-self-producer env, ast

module.exports = ast-to-estree
  ..to-self-producer = ast-to-self-producer
