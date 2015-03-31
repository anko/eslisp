concat = require \concat-stream
{ zip } = require \prelude-ls
spawn = (require \child_process).spawn
esl = require \./index
require! <[ async fs path ]>
args = (require \nomnom)
  .script \eslc
  .nocolors true
  .option \path do
    position : 0
    help : "source file (if absent, stdin is read)"
  .option \version do
    flag : true
    help : "print version, exit"
    abbr : \v
  .parse!


if args.version
  try
    console.log (JSON.parse fs.read-file-sync \../package.json .version)
    process.exit 0
  catch e
    console.error e
    console.error "Unknown version; error reading or parsing package.json"
    process.exit 1

show-that = -> console.log esl it

if args.path
  e, esl-code <- fs.read-file args.path, encoding : \utf8
  if e then throw e
  show-that esl-code
else
  process.stdin .pipe concat (esl-code) ->
    if e then throw e
    show-that esl-code
