compile = require './compile'

###
# rmutt
###
module.exports =

  compile: compile

  generate: (source, config) ->
    config ?= {}

    if typeof source is 'string'
      compiled = compile source, config
    else if typeof source is 'function'
      compiled = source

    compiled config
