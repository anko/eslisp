concat = require \concat-stream
{ zip } = require \prelude-ls
spawn = (require \child_process).spawn
esl = require \./index
require! <[ async fs path ]>

print-usage = ->
  console.log do
    "Usage: eslc [-h] [-v] [FILE]\n" +
    "  FILE           file to read (stdin if omitted)\n" +
    "  -v, --version  print version, exit\n" +
    "  -h, --help     print usage, exit"

print-version = ->
  try
    console.log (require \../package.json .version)
    process.exit 0
  catch e
    console.error e
    console.error "Unknown version; error reading or parsing package.json"
    process.exit 1

target-path = null

process.argv
  .slice 2 # chop "node scriptname"
  .for-each ->
    switch it
    | \-v => fallthrough
    | \--version => print-version! ; process.exit!
    | \-h => fallthrough
    | \--help => print-usage! ; process.exit!
    | otherwise =>
      if target-path
        console.error "Too many arguments (expected 0 or 1 files)"
        process.exit 2
      else
        target-path := it

show-that = -> console.log esl it

if target-path
  e, esl-code <- fs.read-file target-path, encoding : \utf8
  if e then throw e
  show-that esl-code
else
  process.stdin .pipe concat (esl-code) ->
    show-that esl-code
