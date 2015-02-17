concat  = require \concat-stream
lex     = require \./lex.ls
parse   = require \./parse.ls
compile = (require \escodegen).generate _

print-and-pass-on = -> console.log JSON.stringify it ; return it
module.exports = (input) ->
  "(#input)" # Implicit list around everything
  |> lex
  # |> print-and-pass-on
  |> parse
  |> print-and-pass-on
  |> compile
  # |> print-and-pass-on
