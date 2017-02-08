concat  = require \concat-stream
{ zip } = require \prelude-ls
spawn   = (require \child_process).spawn
esl     = require \./index
require! <[ fs path nopt chalk ]>
require! \convert-source-map

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
  console.log """
  Usage: eslc [-h] [-v] [-t require-path] [-s MAP-FILE] [-S] [FILE]
    FILE                      eslisp file (if omitted, stdin is read)
    -v, --version             print version, exit
    -h, --help                print usage, exit
    -t, --transform           macro to `require` and wrap whole input in; can
                                be specified multiple times
    -s, --source-map-outfile  file to save source map in; remember to add the
                                appropriate `//\# sourceMappingURL=...` comment
                                to the end of your output JS file
    -S, --embed-source-map    store source map in the generated output JS
    """

options =
  version   : Boolean
  help      : Boolean
  transform : Array
  \source-map-outfile : String
  \embed-source-map : Boolean

option-shorthands =
  v : \--version
  h : \--help
  t : \--transform
  s : \--source-map-outfile
  S : \--embed-source-map

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

compile-and-show = (code, filename=null) ->
  code .= to-string!
  try

    opt-map-out = parsed-options[\source-map-outfile]
    opt-map-embed = parsed-options[\embed-source-map]

    var js-code, js-map

    compiler-opts.filename = filename

    if opt-map-out or opt-map-embed

      # Receive both code and source map from the compiler.
      { code, map } = esl.with-source-map code, compiler-opts
      js-code := code
      js-map  := map

    else

      # Run the standard compiler, without generating a source map.
      js-code := esl code, compiler-opts
      js-map  := null

    if opt-map-out
      # Write out the source map to the specified file.
      fs.write-file that, map, (e) ->
        if e
          console.error "Error writing to source map output file #that"
          process.exit 5
    if opt-map-embed

      source-map-data-uri-comment = convert-source-map
        .from-JSON js-map
        .to-comment!

      js-code += "\n#source-map-data-uri-comment"

    # Print finished JavaScript to stdout.
    console.log js-code

  catch err
    if err instanceof InvalidAstError
      console.error (chalk.red "[Error]") + " " + err.message
      point-at-problem code, err.node
    else throw err

string-splice = (string, start, end, inserted-text="") ->
    (string.slice 0, start) +
      inserted-text +
      (string.slice end, string.length)

# Use the node's location data (if present) to show the lines on which the
# problem occurred.
point-at-problem = (input, problematic-node) ->
  { loc : location } = problematic-node
  switch typeof! location
  | \String =>
    stringified-node = JSON.stringify do
      problematic-node
      (k, v) -> if k is \location then undefined else v
    console.error "  #stringified-node"
    console.error chalk.yellow "  [ #location ]"
  | \Object =>
    { start, end } = location
    lines = input
      .split "\n"
      .slice (start.line - 1), end.line
      .join "\n"

    # Subtract 1 from both offsets because of open-paren that's implicitly
    # added to the input
    # inputs.
    start-offset = start.offset
    end-offset   = end.offset

    highlighted-part = chalk.black.bg-yellow (lines.slice start-offset, end-offset)

    highlighted-lines = string-splice do
      lines
      start-offset
      end-offset
      highlighted-part

    console.error "At line #{chalk.green start.line}, \
                   offset #{chalk.green start-offset}:"
    console.error "\n#highlighted-lines\n"

  | _ => throw Error "Internal error: unexpected location type"

if target-path
  e, esl-code <- fs.read-file target-path, encoding : \utf8
  if e then throw e
  compile-and-show esl-code, target-path
else
  # Non-interactive stdin: pipe and compile
  if not process.stdin.isTTY
    if parsed-options[\source-map-outfile]
      console.error """
      Given --source-map-outfile flag, but code was input on stdin
      instead of by file path.  Source maps require a file name:
      please specify the input file by a filename.
      """
      process.exit 3
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
      use-global : yes
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
            console.error (chalk.red "[Error]") + " " + err.message
            point-at-problem cmd, err.node
            callback null
          else throw err
