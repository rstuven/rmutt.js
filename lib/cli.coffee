fs = require 'fs'
path = require 'path'
program = require 'commander'
rmutt = require '..'
product = require '../package.json'

program
  .version(product.version)
  .usage('[grammarfile] [options]')

  .option('-c --cache',
    'If specified, load or create a cached transpiled code file')

  .option('--cache-file <filepath>',
    'Absolute path and file name where the transpiled code will be cached.')

  .option('--cache-regenerate',
    'If specified, write the transpiled file even if it already exists.')

  .option('-e --entry <rule>',
    'Rule to expand first.')

  .option('-i --iteration <integer>',
    'Generate the i-th iteration of N possible combinations. ', parseInt)

  .option('-s --max-stack-depth <integer>',
    'Maximum depth to which rmutt will expand the grammar.', parseInt)

  .option('-r --random-seed <integer>',
    'Seed for the random number generator.', parseInt)

  .option('-t --transpile',
    'Output transpiled code instead of rule expansion.')

  .parse(process.argv)

options = {}
[
  'cache'
  'cacheFile'
  'cacheRegenerate'
  'entry'
  'iteration'
  'maxStackDepth'
  'randomSeed'
].forEach (name) ->
  options[name] = program[name]

# console.log program.args
# console.log options

expand = (source) ->
  options.header = file
  rmutt.expand source, options, (err, result) ->
    return process.stderr.write err.stack if err?
    process.stdout.write result.expanded

transpile = (source) ->
  options.header = file
  rmutt.transpile source, options, (err, result) ->
    return process.stderr.write err.stack if err?
    process.stdout.write result.transpiled

readStream = (stream) ->
  source = ''
  stream.on 'readable', ->
    chunk = stream.read()
    source += chunk if chunk?
  stream.on 'end', ->
    if program.transpile
      transpile source
    else
      expand source

if program.args[0]?
  file = path.join process.cwd(), program.args[0]
  stream = fs.createReadStream file, encoding: 'utf8'
  readStream stream
else
  process.stdin.setEncoding 'utf8'
  readStream process.stdin
