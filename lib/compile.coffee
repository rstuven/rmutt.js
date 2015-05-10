_ = require 'lodash'
fs = require 'fs'
os = require 'os'
path  = require 'path'
hash = require 'string-hash'
transpile = require './transpile'

# TODO: stats

###
# compile
###
module.exports = (source, options, callback) ->
  if callback?
    options ?= {}
  else
    callback = options
    options = {}

  compileTranspiled = (err, transpiled) ->
    # console.log transpiled
    return callback err if err?
    module = {}
    try
      compiled = new Function 'module', transpiled
      compiled module
    catch err
      return callback err

    callback null, module.exports

  cache = options.cache ? false
  if cache
    readOrCreateCache source, options, compileTranspiled
  else
    transpile source, options, compileTranspiled

readOrCreateCache = (source, options, callback) ->
  # TODO: include in hash modifications dates of rmutt.pegjs, parse.coffee & transpile.coffee
  try
    cached = options.cacheFile ? path.join os.tmpdir(), 'rmutt_' + hash source
    if options.cacheRegenerate isnt true and fs.existsSync cached
      console.log 'Loading cache: ', cached
      fs.readFile cached, callback
    else
      transpile source, options, (err, transpiled) ->
        return callback err if err?
        fs.writeFile cached, transpiled, (err) ->
          callback err
  catch err
    callback err
