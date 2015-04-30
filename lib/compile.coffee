_ = require 'lodash'
parse = require './parse'
transpile = require './transpile'

###
# compile
###
module.exports = (source) ->
  rules = parse source
  compiled = new Function '$config', transpile rules
  # console.log compiled.toString()
  compiled
