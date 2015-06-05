concat    = require \concat-stream
parse     = require \./parse
translate = require \./translate
compile   = (require \escodegen).generate _

module.exports = (input) ->
  input .= to-string!

  # Ignore first line if it starts with a shebang
  if input.match /^(#!.*\n)/ then input .= slice that.1.length

  "(#input\n)" # Implicit list of everything (trailing \n terminates comments)
  |> parse
  |> translate
  |> compile
