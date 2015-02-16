#!/usr/bin/env lsc
test = (name, test-func) ->
  (require \tape) name, (t) ->
    test-func.call t  # Make `this` refer to tape's asserts
    t.end!            # Automatically end tests

esl = require \./index.ls

test "plain expression" ->
  esl "(+ 3 4 5)"
    ..`@equals` "3 + (4 + 5);"

test "func expression" ->
  esl "(lambda (x) (+ x 1))"
    ..`@equals` "(function (x) {\n    return x + 1;\n});"

test "assignment expression" ->
  esl "(:= f (lambda (x) (+ x 1)))"
    ..`@equals` "f = function (x) {\n    return x + 1;\n};"

test "empty statement" ->
  esl "()"
    ..`@equals` ";"

test "member expression" ->
  esl "(. console log)"
    ..`@equals` "console.log;"

/*
test "what" ->
  @equals do
    esl """
    (macro eight () (+ 3 5))
    (eight)
    """
    "8"
