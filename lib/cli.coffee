fs = require 'fs'
path = require 'path'
rmutt = require '..'

generate = (source) ->
  rmutt.generate source, header: file, (err, result) ->
    return process.stderr.write err.stack if err?
    process.stdout.write result.generated

readStream = (stream) ->
  source = ''
  stream.on 'readable', ->
    chunk = stream.read()
    source += chunk if chunk?
  stream.on 'end', ->
    generate source

if process.argv[2]?
  file = path.join process.cwd(), process.argv[2]
  stream = fs.createReadStream file, encoding: 'utf8'
  readStream stream
else
  process.stdin.setEncoding 'utf8'
  readStream process.stdin
