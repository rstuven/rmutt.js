_ = require 'lodash'
fs = require 'fs'
os = require 'os'
path  = require 'path'
hash = require 'string-hash'
transpile = require './transpile'

# TODO: stats
# TODO: async

###
# compile
###
module.exports = (source, options) ->
  cache = options?.cache ? false
  if cache
    transpiled = readOrCreateCache source, options
  else
    transpiled = transpile source, options

  # console.log transpiled
  compiled = new Function 'module', transpiled

  module = {}
  compiled module
  return module.exports

readOrCreateCache = (source, options) ->
  # TODO: include in hash modifications dates of rmutt.pegjs, parse.coffee & transpile.coffee
  cached = options.cacheFile ? path.join os.tmpdir(), 'rmutt_' + hash source
  if options.cacheRegenerate isnt true and fs.existsSync cached
    console.log 'Loading cache: ', cached
    transpiled = fs.readFileSync cached
  else
    transpiled = transpile source, options
    fs.writeFileSync cached, transpiled
  transpiled
