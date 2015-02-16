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

test "variable declaration statement" ->
  esl "(= f (lambda (x) (+ x 1)))"
    ..`@equals` "var f = function (x) {\n    return x + 1;\n};"

test "empty statement" ->
  esl "()"
    ..`@equals` ";"

test "member expression" ->
  esl "(. console log)"
    ..`@equals` "console.log;"

test "call expression" ->
  esl "(f)"
    ..`@equals` "f();"

test "member, then call with arguments" ->
  esl '((. console log) "hi")'
    ..`@equals` "console.log('hi');"

test "func with member and call in it" ->
  esl "(lambda (x) ((. console log) x))"
    ..`@equals` "(function (x) {\n    return console.log(x);\n});"

test "if statement" ->
  esl '(if (+ 1 0) ((. console log) "yes") ((. console error) "no"))'
    ..`@equals` "if (1 + 0)\n    console.log(\'yes\');\nelse\n    console.error(\'no\');"

test "ternary expression" ->
  esl '(?: "something" 0 1)'
    ..`@equals` "'something' ? 0 : 1;"

/*
test "what" ->
  @equals do
    esl """
    (macro eight () (+ 3 5))
    (eight)
    """
    "8"
