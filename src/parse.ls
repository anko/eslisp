# Turns an input S-expression string into a simple tree format based on JS
# objects.

parse-sexpr = require \sexpr-plus .parse
{ list, atom, string } = require \./ast

# This serves as an adapter from the s-expression module's way of returning
# things to eslisp AST objects.
make-explicit = (tree) ->
  sexpr-type = (thing) ->
    switch typeof! thing
    | \String =>
      switch typeof thing
      | \object => \string
      | \string => \atom
    | \Array => \list
    | otherwise => null

  switch sexpr-type tree
  | \list   => list   tree.map make-explicit
  | \atom   => atom   tree.to-string!
  | \string => string tree.to-string!
  | null    => throw Error "Unexpected type `#that` (of `#tree`)"

module.exports = parse-sexpr >> make-explicit
