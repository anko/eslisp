looks-like-number = (atom-text) ->
  atom-text.match /^\d+(\.\d+)?$/
looks-like-negative-number = (atom-text) ->
  atom-text.match /^-\d+(\.\d+)?$/

estraverse = require \estraverse .traverse

add-location = (estree, location) ->
  estraverse estree, enter : ->
    if it.location then return
    else it.location = location
  return estree

class string
  (@content-text, @location) ~>
    if not @location
      throw Error "Internal compiler logic error: \
                   string constructed without location parameter"

  text : ->
    return @content-text if not it?
    @content-text := it

  as-sm : ->
    add-location do
      * type : \Literal
        value : @content-text
        raw : "\"#{@content-text}\""
      * @location

  compile : ->
    add-location do
      * type : \Literal
        value : @content-text
        raw : "\"#{@content-text}\""
      * @location

class atom
  (@content-text, @location) ~>
    if not @location
      throw Error "Internal compiler logic error: \
                   atom constructed without location parameter"

  text : ->
    return @content-text if not it?
    @content-text := it

  is-number: -> (looks-like-number @content-text)
             || (looks-like-negative-number @content-text)

  as-sm : ->
    r = if @is-number!
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
    return add-location r, @location

  compile : ->

    lit = ~> type : \Literal, value : it, raw : @content-text

    r = switch @content-text
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
    return add-location r, @location

class list
  (@content=[], @location) ~>
    if not @location
      throw Error "Internal compiler logic error: \
                   list constructed without location parameter"

  contents : ->
    return @content if not it?
    @content := it

  as-sm : ->
    add-location do
      type : \ArrayExpression elements : @content.map (.as-sm!)
      @location

  compile : (env) ->

    return null if @content.length is 0

    [ head, ...rest ] = @content

    return null unless head

    local-env = env.derive!

    r = if head instanceof atom
    and local-env.find-macro head.text!

      that.apply null, ([ local-env ] ++ rest)

    else
      # TODO compile-time check if callee has sensible type
      type : \CallExpression
      callee : head.compile local-env
      arguments : rest.map (.compile local-env)

    if r instanceof Array
      r.for-each ~> add-location it, @location
    else
      add-location r, @location
    r

module.exports = { atom, string, list }
