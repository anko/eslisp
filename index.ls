#!/usr/bin/env lsc

concat  = require \concat-stream
lex     = require \./lex.ls
parse   = require \./parse.ls
compile = (require \escodegen).generate _

print-and-pass-on = -> console.log JSON.stringify it ; return it
module.exports = (input) ->
  input |> lex
  # |> print-and-pass-on
  |> parse |> compile
  # |> print-and-pass-on
