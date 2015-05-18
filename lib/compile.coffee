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

  options = _.clone options

  compileTranspiled = (err, result) ->
    return callback err if err?
    module = {}
    try
      compiled = new Function 'module', result.transpiled
      compiled module
    catch err
      return callback err

    callback null,
      compiled: module.exports
      options: result.options

  options.cache ?= false
  if options.cache
    readOrCreateCache source, options, compileTranspiled
  else
    transpile source, options, compileTranspiled

readOrCreateCache = (source, options, callback) ->
  # TODO: include in hash modifications dates of rmutt.pegjs, parse.coffee & transpile.coffee
  try
    options.cacheFile ?= path.join os.tmpdir(), 'rmutt_' + hash source
    if options.cacheRegenerate isnt true and fs.existsSync options.cacheFile
      # console.log 'Loading cache: ', options.cacheFile
      fs.readFile options.cacheFile, (err, result) ->
        return callback err if err?
        callback null,
          transpiled: result
          options: options
    else
      transpile source, options, (err, result) ->
        return callback err if err?
        fs.writeFile options.cacheFile, result.transpiled, (err) ->
          return callback err if err?
          callback null,
            transpiled: result.transpiled
            options: options
  catch err
    callback err
