# Turns an input S-expression string into a simple tree format based on JS
# objects.

parse-sexpr = require \s-expression

# This serves as an adapter from the s-expression module's way of returning
# things to a more explicit JS object representation.
make-explicit = (tree) ->
  sexpr-type = (thing) ->
    switch typeof! thing
    | \String =>
      switch typeof thing
      | \object => \string
      | \string => \atom
    | \Array => \list
    | _ => throw Error "Unexpected type `#that` (of `#thing`)"

  switch sexpr-type tree
  | \list => type : \list, contents : tree.map make-explicit
  | \atom => fallthrough
  | \string => type : that, text : tree.to-string!

module.exports = parse-sexpr >> make-explicit
