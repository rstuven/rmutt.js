transpile = require './transpile'
compile = require './compile'

###
# rmutt
###
module.exports =

  transpile: transpile

  compile: compile

  generate: (source, config) ->
    config ?= {}

    if typeof source is 'string'
      compiled = compile source, config
    else if typeof source is 'function'
      compiled = source

    compiled config
