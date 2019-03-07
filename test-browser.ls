# A script to run the test suite in a headless Chromium
#
# It's pretty much just Browserify everything, put it in an HTML page and tell
# puppeteer to load it.
#
# The source-map package deciding to move to a WASM implementation causes us
# some headache here: we have to make sure its mappings.wasm file is in the
# right place so the browser can pick it up.

require! <[ puppeteer tmp fs browserify http ecstatic ]>

e, directory <- tmp.dir prefix: \eslisp-browser-test_ ; throw e if e
filepath = "#directory/index.html"

browserify-spec = browserify \./test.ls { +debug }
  ..transform \anyify ls: \livescript?compile
e, js <- browserify-spec.bundle! ; throw e if e

console.log "Generating HTML into #filepath"
e <- fs.write-file do
  filepath
  """
  <html>
    <head> <meta charset="utf-8"/> </head>
    <script> #js </script>
  </html>
  """
wasm-filepath = "#directory/mappings.wasm"
console.log "Copying source-map WASM into #wasm-filepath"
e <- fs.copy-file \node_modules/source-map/lib/mappings.wasm wasm-filepath
throw e if e

http-server = http.create-server (ecstatic root: directory) .listen 9999

(->>
  got-error = false
  got-fail = false
  browser = await puppeteer.launch args: <[ --no-sandbox ]>
  console.log "Browser version #{await browser.version!}"
  console.log!
  page = await browser.new-page!
    ..on \console (msg) ->
      console.log msg.text!
      if msg.text!.starts-with 'not ok'
        got-fail := true
    ..on \error (msg) ->
      got-error := true
      console.error "error msg:" msg
    ..on \pageerror (msg) ->
      console.error "pageerror msg:" msg
      got-error := true
    await ..goto "http://localhost:9999/index.html" wait-until: \networkidle2
  await browser.close!
  if got-fail
    process.exit 1
  if got-error
    process.exit 2
  <- http-server.close!
)!
