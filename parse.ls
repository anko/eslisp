# Takes in an S-expression.
# Puts out a corresponding SpiderMonkey AST.

{ lists-to-obj } = require \prelude-ls

compile = (node) ->
  switch node.type
  | \string => node.text
  | \atom   =>
    if node.text .match /\d+(\.\d+)?/
      Number node.text
    else node.text
  | \list =>
    [ head, ...rest ] = node.contents
    switch head.type
    | \atom =>
      switch head.text
      | \object => # object constructor
        # Parse rest as alternating object keys and values
        unless (rest.length % 2) is 0
          throw Error "Odd number of arguments to `#that`: expected even"
        keys = [] ; values = []
        rest.for-each (x, i) ->
          (if (i % 2) is 0 then keys else values)
            ..push compile x
        lists-to-obj keys, values
      | \array => # array constructor
        rest.map compile
    | \string => fallthrough
    | \list   => throw Error "Unexpected #that at head of list"

module.exports = compile
