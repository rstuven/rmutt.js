rmutt = require '..'
expect = require('chai').expect

describe 'examples', ->

  examplesDir = __dirname + '/../examples/'

  LOG_OUTPUT = false

  options =
    workingDir: examplesDir
    cache: false
    cacheRegenerate: true

  # TODO: skipped errors
  examples =
    addresses: null
    author: null
    bands: null
    chars: null
    dialogue: null
    directions: null
    dissertation: null
    dotree: null
    eng: null
    gramma: null
    grammar: null
    jcr_sv: null
    math: null
    neruda: null
    numbers: null
    password: null
    password2: null
    recipe: null
    sentence: null
    slogan: null
    spew: null
    spew_xml: null
    story: null
    sva: null
    tree: null
    turing: null
    url: null
    wine: null
    xml: null

  example = (name) ->
    fs = require 'fs'
    file  = name + '.rm'
    grammar = fs.readFileSync examplesDir + file, 'utf8'
    # console.log grammar

    if LOG_OUTPUT
      console.log('\n' + file + ':')

    # console.time('compile')
    options.header = file
    generator = rmutt.compile grammar, options
    # console.timeEnd('compile')
    # console.log generator.toString()

    # console.time('generate')
    output = generator()
    # console.timeEnd('generate')

    if LOG_OUTPUT
      console.log()
      console.log output

  Object.keys(examples).forEach (name) ->
    action = examples[name]
    test = -> example name
    if action?
      it[action] name, test
    else
      it name, test
