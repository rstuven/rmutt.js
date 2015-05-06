transpile = require './transpile'
compile = require './compile'

###
# rmutt
###
module.exports =

  transpile: transpile

  compile: compile

  generate: (source, options) ->
    options ?= {}

    if typeof source is 'string'
      compiled = compile source, options
    else if typeof source is 'function'
      compiled = source

    compiled options
