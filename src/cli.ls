concat  = require \concat-stream
{ zip } = require \prelude-ls
spawn   = (require \child_process).spawn
esl     = require \./index
require! <[ fs path nopt ]>

{ InvalidAstError } = require \esvalid

print-version = ->
  try
    console.log (require \../package.json .version)
    process.exit 0
  catch e
    console.error e
    console.error "Unknown version; error reading or parsing package.json"
    process.exit 1

print-usage = ->
  console.log do
    "Usage: eslc [-h] [-v] [-t require-path] [FILE]\n" +
    "  FILE           file to read (if omitted, stdin is assumed)\n" +
    "  -v, --version    print version, exit\n" +
    "  -h, --help       print usage, exit\n" +
    "  -t, --transform  macro to wrap whole input in\n" +
    "                     given path is passed to `require`\n" +
    "                     can be specified multiple times"

options =
  version   : Boolean
  help      : Boolean
  transform : Array

option-shorthands =
  v : \--version
  h : \--help
  t : \--transform

parsed-options = nopt do
  options
  option-shorthands
  process.argv

do
  var exit-after

  if parsed-options.version
    print-version!
    exit-after := true
  if parsed-options.help
    print-usage!
    exit-after := true

  if exit-after then process.exit!

target-path = null

parsed-options.argv.remain
  .for-each ->
    if target-path
      console.error "Too many arguments (expected 0 or 1 files)"
      process.exit 2
    else
      target-path := it

compiler-opts = {}
if parsed-options.transform
  compiler-opts.transform-macros = that .map require

compile-and-show = (code) ->
  code .= to-string!
  try
    console.log esl code, compiler-opts
  catch err
    if err instanceof InvalidAstError
      console.error "[Error]" err.message
      point-at-problem code, err.node
    else throw err

# Use the node's location data (if present) to show the lines on which the
# problem occurred.
point-at-problem = (input, problematic-node) ->
  { location } = problematic-node
  switch typeof! location
  | \String =>
    stringified-node = JSON.stringify do
      problematic-node
      (k, v) -> if k is \location then undefined else v
    console.error "  #stringified-node"
    console.error "  [ #location ]"
  | \Object =>
    { start, end } = location
    line = input
      .split "\n"
      .slice (start.line - 1), end.line
      .join "\n"
    underline = " " * (start.offset - 1) +
                "^" * (end.offset - start.offset)
    console.error "  " + line
    console.error "  " + underline
  | _ => throw Error "Internal error: unexpected location type"

if target-path
  e, esl-code <- fs.read-file target-path, encoding : \utf8
  if e then throw e
  compile-and-show esl-code
else
  # Non-interactive stdin: pipe and compile
  if not process.stdin.isTTY
    process.stdin .pipe concat compile-and-show

  # Interactive stdin: start repl
  else

    # Create a stateful instance of the compiler that holds on to a root macro
    # environment.  This lets typed-in macros persist for the session.
    stateful-compiler = esl.stateful compiler-opts

    # see https://nodejs.org/api/repl.html
    repl = require \repl
    vm = require \vm
    repl.start do
      prompt: "> "
      eval: (cmd, context, filename, callback) ->
        # NOTE: will fail on older nodejs due to paren wrapping logic; see
        # SO http://stackoverflow.com/questions/19182057/node-js-repl-funny-behavior-with-custom-eval-function
        # GH https://github.com/nodejs/node-v0.x-archive/commit/9ef9a9dee54a464a46739b14e8a348bec673c5a5
        try
          stateful-compiler cmd
          |> vm.run-in-this-context
          |> callback null, _
        catch err
          if err instanceof InvalidAstError
            console.error "[Error]" err.message
            point-at-problem cmd, err.node
            callback null
          else throw err
