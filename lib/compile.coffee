_ = require 'lodash'
fs = require 'fs'
os = require 'os'
path  = require 'path'
hash = require 'string-hash'
parse = require './parse'
transpile = require './transpile'

###
# compile
###
module.exports = (source, config) ->
  cache = config?.cache ? false
  if cache
    transpiled = readOrCreateCache source, config
  else
    transpiled = transpile parse source, config

  # console.log transpiled
  compiled = new Function 'module', transpiled

  module = {}
  compiled module
  return module.exports

readOrCreateCache = (source, config) ->
  cached = config.cacheFile ? path.join os.tmpdir(), 'rmutt_' + hash source
  if config.cacheRegenerate isnt true and fs.existsSync cached
    console.log 'Loading cache: ', cached
    transpiled = fs.readFileSync cached
  else
    transpiled = transpile parse source, config
    fs.writeFileSync cached, transpiled
  transpiled
