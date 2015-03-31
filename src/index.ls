concat  = require \concat-stream
lex     = require \./lex
parse   = require \./parse
compile = (require \escodegen).generate _

module.exports = (input) ->
  "(#input)" # Implicit list around everything
  |> lex
  |> parse
  |> compile
