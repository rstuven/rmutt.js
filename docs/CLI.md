## rmutt.js command-line interface

### Usage

**rmutt.js** has a command-line interface which accepts a [rmutt grammar](GUIDE.md) as an input. Install it:

    $ npm install --global rmutt

> [node.js](https://nodejs.org/) is a prerequisite.

The general form to use it is:

    $ rmutt [gramarfile] [options]

> **rmutt** *does not* require any filename extension, but often you'll see we arbitrarily use `.rm`.

If you have a file with an **rmutt** grammar on it, you can mention it on the command line like this:

    $ rmutt myfile.rm

If you want to save the output to a file you can simply redirect it:

    $ rmutt myfile.rm > myoutputfile

Both grammar file and options are not required.

If you have a program which generates an **rmutt** grammar, you can pipe it through `rmutt` command. For example:

```
$ echo "night-sky:('.' 5, ' ' 100, '*'){100000};" | rmutt
```

(without double quotes in Windows)

### Options

### `-h`, `--help`
Output usage information and exit.

### `-V`, `--version`
Output version and exit.

### `-c`, `--cache`
If specified, load or create a cached transpiled code file.

### `--cache-file <filepath>`
Absolute path and file name where the transpiled code will be cached.

### `--cache-regenerate`
If specified, write the transpiled file even if it already exists.

### `-e`, `--entry <rule>`
In order to produce a string, **rmutt** must start with one of the rules in the grammar. By default, **rmutt** expands the first rule it finds in the grammar, but you can use this option to specify another one.

### `-i`, `--iteration <integer>`
A given **rmutt** grammar can generate *N* possible strings, where *N* is finite or infnite depending on whether or not the grammar is recursive. Specifying an iteration will deterministically generate the *N*-th possible string. If the iteration specified (call it *i*) is greater than *N*, **rmutt** will generate the `i mod N`th iteration. Enumerating all possible strings of a grammar is usually only useful for very simple grammars; most grammars can produce more strings than can be enumerated with a JavaScript number.

### `-s`, `--max-stack-depth <integer>`
Specifies the maximum depth to which **rmutt** will expand the grammar. This is usually used to prevent recursive grammars from crashing **rmutt** with stack overflows. Beyond the maximum stack depth, a rule will expand to an empty, zero-length string.

### `-r`, `--random-seed <integer>`
Specifies a seed for the random number generator. Two runs against the same grammar with the same seed will generate identical output. The seed must be a 32-bit integer. If no seed is specified, a seed is generated and can be expanded in the grammar using the [`$options.randomSeed`](./GUIDE.md#options-package) rule.

### `-t`, `--transpile`
Output transpiled code instead of rule expansion.
