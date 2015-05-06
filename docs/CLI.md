## rmutt.js command-line interface

**rmutt.js** has a command-line interface which accepts a [rmutt grammar](GUIDE.md) as an input. Install it:

    $ npm install --global rmutt

If you have a file with an **rmutt** grammar on it, you can mention it on the command line like this:

    $ rmutt myfile.rm

If you want to save the output to a file you can simply redirect it:

    $ rmutt myfile.rm > myoutputfile

If you have a program which generates an **rmutt** grammar, you can pipe it through `rmutt` command. For example:

```
$ echo "night-sky:('.' 5, ' ' 100, '*'){100000};" | rmutt
```

(without double quotes in Windows)

Note: **rmutt** does not require that the names of grammar files end with `.rm` or any other specific extension.

### Options

No options are implemented at the moment. These will be most of the ones available for the [JavaScript API](API.md).
