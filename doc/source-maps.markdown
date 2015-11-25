# Using source maps

The eslisp compiler supports [source maps][1] via compiler flags.  Source maps
are a file format that various JavaScript development tools can read, and use
to associate generated JavaScript code with locations in the original source
files it was compiled from.

## Embedded source map

The easiest way to get a source map from the eslisp compiler is to add an
`--embed-source-map` flag to `eslc`.

The output JavaScript will look something like—

    console.log('Hello!');
    //# sourceMappingURL=data:application/json;base64,eyJ2ZXJzaW9uIjozLCJzb3VyY2VzIjpbInRlc3QuZXNsIl0sIm5hbWVzIjpbImNvbnNvbGUiLCJsb2ciXSwibWFwcGluZ3MiOiJBQUFJQSxPQUFGLENBQVVDLEdBQVosQ0FBaUIsUUFBakIsQyIsInNvdXJjZXNDb250ZW50IjpbIigoLiBjb25zb2xlIGxvZykgXCJIZWxsbyFcIilcbiJdfQ==

—where that last line contains an encoded version of the original eslisp
source, and all mappings from one to the other.

Note that because source maps require a file name, you'll need to pass a file
name to `eslc`.  (You can't generate source maps for code received on `stdin`).

## External source map

You can also generate a source map to a file, if you have a custom setup or are
concerned about file size.  This is done with the `--source-map-outfile` flag,
which expects to be given a path to a target file.

The JavaScript source code is output on `stdout` regardless.

Note that to tell dev tools about the source map, you'll have to add an
appropriate `//# sourceMappingURL=...`-line to the generated JavaScript
yourself.  Eslisp doesn't do this because it makes no assumptions about your
web server's directory structure.

For example, if a source map is available at `/js/map/test.js.map` on your web
server, you might want to have a build step that adds the line—

    //# sourceMappingUrl=/js/map/test.js.map

—to the end of the generated `test.js` file.

## Generating a source map with the module API

If you're using the eslisp compiler as a module, you can also use it to compile
simultaneously to a source map and a JavaScript program:
`require("eslisp").withSourceMap` takes the same arguments as the basic
compiler, but returns a `{ code, map }` object.

[1]: http://www.html5rocks.com/en/tutorials/developertools/sourcemaps/
