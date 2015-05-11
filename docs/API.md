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

<a name="generator-callback" />
### callback
A function with the following arguments:
* **error** (Error)
* **result** (object): An object with the following properties:
  * **options** (object): The options used (some may have changed during execution).
  * **generated** (string): The generated text.

### options

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
}, function (err, result) {
  // result.generated = "1 + 2 = 3"
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
}, function (err, result) {
  // result.generated = "1 + 2 = USD 3"
});
```

* **iteration** (number):
A given **rmutt** grammar can generate *N* possible strings, where *N* is finite or infnite depending on whether or not the grammar is recursive. Specifying an iteration will deterministically generate the *N*-th possible string. If the iteration specified (call it *i*) is greater than *N*, **rmutt** will generate the `i mod N`th iteration. Enumerating all possible strings of a grammar is usually only useful for very simple grammars; most grammars can produce more strings than can be enumerated with a JavaScript number.

* **maxStackDepth** (number):
Specifies the maximum depth to which **rmutt** will expand the grammar. This is usually used to prevent recursive grammars from crashing **rmutt** with stack overflows. Beyond the maximum stack depth, a rule will expand to an empty, zero-length string.

* **randomSeed** (number|Array):
Specifies a seed for the random number generator. Two runs against the same grammar with the same seed will generate identical output. The seed can be a single 32-bit integer or an array of 16 32-bit integers. If no seed is specified, a seed is generated according to **randomSeedType** option and returned in the [callback result options](generator-callback).

<a name="generator-options-randomSeedType" />
* **randomSeedType** (string):
Specifies the type of the random seed if this has to be generated. Valid values are:
  * `"integer"` (default)
  * `"array"`

This option overrides the [`randomSeedType` option](#transpile-options-randomSeedType) passed to
[`rmutt.transpile`](#transpile) or [`rmutt.compile`](#compile).

### Example

``` javascript
rmutt.compile(grammar, function (err, result) {
  var generator = result.compiled;
});
```
Or...
``` javascript
var generator = require('path/to/transpiled/file');
```
Then
``` javascript
generator(function (err, result) {
  console.log(result.generated);
});
```

<a name="compile" />
## rmutt.compile(grammar[, options], callback)
Creates a [`generator`](#generator) function.

### callback
A function with the following arguments:
* **error** (Error)
* **result** (object): An object with the following properties:
  * **options** (object): The options used (some may have changed during execution).
  * **compiled** (Function): The [`generator`](#generator) function.

### options

* **cache** (boolean):
Loads or creates a cached transpiled code file.

* **cacheFile** (string):
Absolute path and file name where the transpiled code will be cached.

* **cacheRegenerate** (boolean):
Always create the transpiled file.

### Example

``` javascript
rmutt.compile(grammar, {entry: 'entry-rule'}, function (err, result) {
  result.compiled(function (err, result1) {
  });
  result.compiled(function (err, result2) {
    // depending on the chances, result2.generated is different than result1.generated
  });
});
```

<a name="transpile" />
## rmutt.transpile(grammar[, options], callback)
Generates a string containing JavaScript code that can be saved in a file and later loaded using `require` to obtain a [`generator`](#generator) function.

### callback
A function with the following arguments:
* **error** (Error)
* **result** (object): An object with the following properties:
  * **options** (object): The options used (some may have changed during execution).
  * **transpiled** (string): The generated JavaScript code.

### options

<a name="transpile-options-entry" />
* **entry** (string):
In order to produce a string, **rmutt** must start with one of the rules in the grammar. By default, **rmutt** expands the first rule it finds in the grammar, but you can use this option to specify another one.

This option can be overriden by the [`entry` option](#generator-options-entry) passed to
the [`generator`](#generator) function.

* **header** (string):
Adds a comment line under the *"Generated by rmutt"* line in the transpiled code.

<a name="transpile-options-randomSeedType" />
* **randomSeedType** (string):
Specifies the type of the random seed if this has to be generated. Valid values are:
  * `"integer"` (default)
  * `"array"`

This option can be overriden by the [`randomSeedType` option](#generator-options-randomSeedType) passed to
the [`generator`](#generator) function.

<a name="generate" />
## rmutt.generate(grammar[, options], callback)
Convenience function. Calls [`rmutt.transpile`](#transpile), [`rmutt.compile`](#compile) and executes the [`generator`](#generator) function for the source [`grammar`](GUIDE.md), all in one step, so the options are the same than for those methods.

### Example

``` javascript
rmutt.generate("top: a,b,c,d;", function (err, result) {
  console.log(result.generated);
});
```
