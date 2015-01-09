{ lists-to-obj } = require \prelude-ls
parse-sexpr = require \s-expression

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
