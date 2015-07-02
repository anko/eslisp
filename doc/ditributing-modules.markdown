# How to distribute modules written in eslisp

## eslisp code in npm modules

People will expect your [npm][1] modules to contain JavaScript code, not eslisp
code.  Luckily, npm has a built-in way to automatically run scripts (like
compilation) at appropriate times.  You can read more about it in [the
`package.json` documentation][2], but here's a summary of the killer bit:

Putting `eslc < index.esl > index.js` in your `package.json`'s
`scripts.preinstall` will ensure that `index.esl` is compiled to `index.js` on
`npm install`, `npm publish`, `npm pack` and just generally when it needs to be
put in a usable state.

This means you don't have to track `index.js` in your revision control
([git][3], [Mercurial][4], whatever you use).  And indeed you shouldn't; it's
much cleaner!

If your module requires a more complex build, consider moving to a build system
like [make][5], [grunt][6] or [gulp][7].

## eslisp macros as npm modules

Since eslisp macros are just JavaScript functions that are assumed to take
certain values, you can easily export them from modules that are created just
as above.

Add an appropriate eslisp version range as a [`peerDependency`][8].  This says
what version of eslisp your macro works in.

To prevent confusion, it might be best to use an `eslisp-` prefix on your
package name.

## writing an eslisp-based language

If you'd like to write a bunch of macros and other stuff that construct a whole
new programming language with different abstractions, which uses eslisp as the
back-end, you're very welcome to do that!

It's likely wisest to add eslisp to `dependencies` then.

Call it anything you like, but try to make it different enough from "eslisp"
that they don't get confused.

[1]: https://www.npmjs.com/
[2]: https://docs.npmjs.com/files/package.json
[3]: https://git-scm.com/
[4]: https://mercurial.selenic.com/
[5]: https://en.wikipedia.org/wiki/Make_(software)
[6]: http://gruntjs.com/getting-started
[7]: http://gulpjs.com/
[8]: http://blog.nodejs.org/2013/02/07/peer-dependencies/
