# rmutt.js API

## Install

    $ npm install --save rmutt

``` javascript
var rmutt = require('rmutt');
```

# Functions

* [`generator`](#generator)
* [`rmutt.compile`](#compile)
* [`rmutt.transpile`](#transpile)
* [`rmutt.generate`](#generate)

## Shared options

As internally some methods are reused by others, options of the former also apply to the latter:

* All [`rmutt.transpile`](#transpile) options apply to [`rmutt.compile`](#compile) and [`rmutt.generate`](#generate).
* All [`rmutt.compile`](#compile) options apply to [`rmutt.generate`](#generate).
* All [`generator`](#generator) options apply to [`rmutt.generate`](#generate).

<a name="generator" />
## generator([options, ]callback)
Generates a (usually random) instance of the string specified by the source [grammar](GUIDE.md). This function is created by [`rmutt.compile`](#compile) or returned by a `require` from transpiled code (see [`rmutt.transpile`](#transpile)).

### Options

<a name="generator-options-entry" />
* **entry** (string):
In order to produce a string, **rmutt** must start with one of the rules in the grammar. By default, **rmutt** expands the first rule it finds in the grammar, but you can use this option to specify another one. This option overrides the [`entry` option](#transpile-options-entry) passed to
[`rmutt.transpile`](#transpile) or [`rmutt.compile`](#compile).

<a name="generator-options-externals" />
* **externals** (object):
Most of the time, the expressive generative power of **rmutt** is enough.
But sometimes, implementing a complex rule in pure **rmutt**
*-although almost always possible-* can be hard to write
and later harder to read and maintain.
Besides, there are tons of JavaScript libraries out there we can reuse.
An external rule is a JavaScript function that can be used
as a rule with or without arguments or as a transformation rule.

For instance, take the following grammar:
``` coffeescript
top: expr " = " (expr > xcalc);
expr: "1 + 2";
```
The following example will define the transformation `xcalc`:
``` javascript
rmutt.generate(grammar, {
  externals: {
    xcalc: function (input) {
      return eval(input).toString(); // sorry, the Evil Eval got a part in this story
    }
  }
}, function (err, output) {
  // output = "1 + 2 = 3"
});
```

Another example grammar:
``` coffeescript
top: expr " = " calc[expr, "USD"];
expr: "1 + 2";
```
The following will define the rule with arguments `calc`:
``` javascript
rmutt.generate(grammar, {
  externals: {
    calc: function (input, unit) {
      return unit + ' ' + eval(input).toString();
    }
  }
}, function (err, output) {
  // output = "1 + 2 = USD 3"
});
```

* **iteration** (number):
A given **rmutt** grammar can generate *N* possible strings, where *N* is finite or infnite depending on whether or not the grammar is recursive. Specifying an iteration will generate the *N*-th possible string. If the iteration specified (call it *i*) is greater than *N*, **rmutt** will generate the `i mod N`th iteration. Enumerating all possible strings of a grammar is usually only useful for very simple grammars; most grammars can produce more strings than can be enumerated with a JavaScript number.

* **maxStackDepth** (number):
Specifies the maximum depth to which **rmutt** will expand the grammar. This is usually used to prevent recursive grammars from crashing **rmutt** with stack overflows. Beyond the maximum stack depth, a rule will expand to an empty, zero-length string.

### Example

``` javascript
rmutt.compile(grammar, function (err, generator) {
});
```
Or...
``` javascript
var generator = require('path/to/transpiled/file');
```
Then
``` javascript
generator(function (err, output) {
  console.log(output);
});
```

<a name="compile" />
## rmutt.compile(grammar[, options], callback)
Creates a [`generator`](#generator) function.

### Options

* **cache** (boolean):
Loads or creates a cached transpiled code file.

* **cacheFile** (string):
Absolute path and file name where the transpiled code will be cached.

* **cacheRegenerate** (boolean):
Always create the transpiled file.

### Example

``` javascript
rmutt.compile(grammar, {entry: 'entry-rule'}, function (err, generator) {
  generator(function (err, output1) {
  });
  generator(function (err, output2) {
    // depending on the chances, output2 is different than output1
  });
});
```

<a name="transpile" />
## rmutt.transpile(grammar[, options], callback)
Returns a string containing JavaScript code that can be saved in a file and later loaded using `require` to obtain a [`generator`](#generator) function.

### Options

<a name="transpile-options-entry" />
* **entry** (string):
In order to produce a string, **rmutt** must start with one of the rules in the grammar. By default, **rmutt** expands the first rule it finds in the grammar, but you can use this option to specify another one.

This option can be overriden by the [`entry` option](#generator-options-entry) passed to
the [`generator`](#generator) function.

* **header** (string):
Adds a comment line under the *"Generated by rmutt"* line in the transpiled code.

<a name="generate" />
## rmutt.generate(grammar[, options], callback)
Convenience function. Calls [`rmutt.transpile`](#transpile), [`rmutt.compile`](#compile) and executes the [`generator`](#generator) function for the source [`grammar`](GUIDE.md), all in one step, so the options are the same than for those methods.

### Example

``` javascript
rmutt.generate("top: a,b,c,d;", function (err, output) {
  console.log(output);
});
```