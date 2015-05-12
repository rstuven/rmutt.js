transpile = require './transpile'
compile = require './compile'

###
# rmutt
###
module.exports =

  transpile: transpile

  compile: compile

  expand: (source, options, callback) ->
    if callback?
      options ?= {}
    else
      callback = options
      options = {}

    if typeof source is 'string'
      # source is a grammar
      compile source, options, (err, result) ->
        return callback err if err?
        result.compiled result.options, callback
    else if typeof source is 'function'
      # source is an expander
      source options, callback
    else
      callback new TypeError 'Source argument is not a string (grammar) or a function (expander)'
