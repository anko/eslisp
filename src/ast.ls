looks-like-number = (atom-text) ->
  atom-text.match /^\d+(\.\d+)?$/
looks-like-negative-number = (atom-text) ->
  atom-text.match /^-\d+(\.\d+)?$/
class string
  (@content-text) ~>

  text : ->
    return @content-text if not it?
    @content-text := it

  as-sm : ->
    type : \Literal
    value : @content-text
    raw : "\"#{@content-text}\""

  compile : ->
    type : \Literal
    value : @content-text
    raw : "\"#{@content-text}\""

class atom
  (@content-text) ~>

  text : ->
    return @content-text if not it?
    @content-text := it

  is-number: -> (looks-like-number @content-text)
             || (looks-like-negative-number @content-text)

  as-sm : ->
    if @is-number!
      type  : \Literal
      value : Number @content-text
      raw   : @content-text
    else
      type : \ObjectExpression
      properties : [
        type : \Property
        kind : \init
        key :
          type : \Identifier
          name : \atom
        value  :
          type : \Literal
          value : @content-text
          raw : "\"#{@content-text}\""
      ]

  compile : ->

    lit = ~> type : \Literal, value : it, raw : @content-text

    switch @content-text
    | \this  => type : \ThisExpression
    | \null  => lit null
    | \true  => lit true
    | \false => lit false
    | otherwise switch
      | looks-like-number @content-text
        type  : \Literal
        value : Number @content-text
        raw   : @content-text
      | looks-like-negative-number @content-text
        type     : \UnaryExpression
        operator : \-
        prefix   : true
        argument : lit Number @content-text.slice 1 # trim leading minus
      | otherwise
        type : \Identifier
        name : @content-text

class list
  (@content=[]) ~>

  contents : ->
    return @content if not it?
    @content := it

  as-sm : ->
    type : \ArrayExpression elements : @content.map (.as-sm!)

  compile : (env) ->

    return null if @content.length is 0

    [ head, ...rest ] = @content

    return null unless head

    local-env = env.derive!

    if head instanceof atom
    and local-env.find-macro head.text!

      that.apply null, ([ local-env ] ++ rest)

    else
      # TODO compile-time check if callee has sensible type
      type : \CallExpression
      callee : head.compile local-env
      arguments : rest.map (.compile local-env)

module.exports = { atom, string, list }
