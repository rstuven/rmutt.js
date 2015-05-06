rmutt = require '..'
expect = require('chai').expect

describe 'examples', ->

  examplesDir = __dirname + '/../examples/'

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
    source = fs.readFileSync examplesDir + file, 'utf8'
    # console.log source

    # console.log('\n' + file + ':')
    # console.time('compile')
    compiled = rmutt.compile source,
      workingDir: examplesDir
      header: file
      cache: false
      cacheRegenerate: true
    # console.timeEnd('compile')
    # console.log compiled.toString()

    # console.time('generate')
    output = compiled()
    # console.timeEnd('generate')

    # console.log()
    # console.log output

  Object.keys(examples).forEach (name) ->
    action = examples[name]
    test = -> example name
    if action?
      it[action] name, test
    else
      it name, test
