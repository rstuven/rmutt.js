fs = require 'fs'
path = require 'path'
rmutt = require '..'


generate = (source) ->
  output = rmutt.generate source, header: file
  process.stdout.write output

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
