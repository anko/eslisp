test = (name, test-func) ->
  (require \tape) name, (t) ->
    test-func.call t  # Make `this` refer to tape's asserts
    t.end!            # Automatically end tests

esl = require \./index.ls

test "basic multiplication test" ->
  @equals do
    "var answer = 6 * 7.5;"
    esl """
(object
  "type" "Program"
  "body" (array
           (object
             "type" "VariableDeclaration"
             "declarations" (array
                              (object
                                "type" "VariableDeclarator"
                                "id" (object
                                       "type" "Identifier"
                                       "name" "answer")
                                "init" (object
                                         "type" "BinaryExpression"
                                         "operator" "*"
                                         "left" (object
                                                  "type"  "Literal"
                                                  "value" 6
                                                  "raw"   "6")
                                         "right" (object
                                                   "type"  "Literal"
                                                   "value"  7.5
                                                   "raw"   "7.5"))))
             "kind" "var")))
"""
