concat  = require \concat-stream
{ zip } = require \prelude-ls
spawn   = (require \child_process).spawn
esl     = require \./index
require! <[ fs path nopt ]>

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
    "Usage: eslc [-h] [-v] [FILE]\n" +
    "  FILE           file to read (if omitted, stdin is assumed)\n" +
    "  -v, --version  print version, exit\n" +
    "  -h, --help     print usage, exit"

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

compile-and-show = -> console.log esl it, compiler-opts

if target-path
  e, esl-code <- fs.read-file target-path, encoding : \utf8
  if e then throw e
  compile-and-show esl-code
else
  process.stdin .pipe concat compile-and-show
