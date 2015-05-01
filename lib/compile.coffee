_ = require 'lodash'
parse = require './parse'
transpile = require './transpile'

###
# compile
###
module.exports = (source, config) ->
  rules = parse source, config
  compiled = new Function '$config', transpile rules
  compiled
