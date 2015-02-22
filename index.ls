concat  = require \concat-stream
lex     = require \./lex.ls
parse   = require \./parse.ls
compile = (require \escodegen).generate _

module.exports = (input) ->
  "(#input)" # Implicit list around everything
  |> lex
  |> parse
  |> compile
