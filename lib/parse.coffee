_ = require 'lodash'
fs = require 'fs'
peg = require 'pegjs'
path = require 'path'

PACKAGE_SEPARATOR = '.'

grammar = fs.readFileSync __dirname + '/rmutt.pegjs', 'utf8'
parser = peg.buildParser grammar # TODO: cache

# TODO: async

###
# parse
###
module.exports = (source, config) ->
  rules = {}
  try
    parse source, rules, config?.workingDir
  catch err
    err.message += "\n    at (#{err.file}:#{err.line}:#{err.column})" if err.line? or err.column?
    console.error err
    throw err

  # console.dir rules, depth: 20, colors: true
  rules

include = (file, rules, dir) ->
  fullpath = path.join (dir ? process.cwd()), file
  source = fs.readFileSync fullpath, 'utf8'
  try
    parse source, rules, path.dirname fullpath
  catch err
    err.file = fullpath
    throw err

pack = (name, pkg) ->
  if pkg? and name.indexOf(PACKAGE_SEPARATOR) is -1
    return pkg + PACKAGE_SEPARATOR + name
  name

packReplace = (name, pkg) ->
  parts = name.split PACKAGE_SEPARATOR
  name = parts[parts.length - 1]
  if pkg?
    pkg + PACKAGE_SEPARATOR + name
  else
    name

packDeep = (node, pkg) ->
  return unless pkg?

  if node.type in ['Call', 'Assignment']
    node.name = pack node.name, pkg
    if node.args?
      for arg in node.args
        packDeep arg, pkg

  if node.type is 'Rule' and node.args?
    node.args.forEach (arg, i) ->
      node.args[i] = pack arg, pkg

  if node.items?
    for item in node.items
      packDeep item, pkg

  packDeep node.expr, pkg if node.expr?
  packDeep node.func, pkg if node.func?
  packDeep node.replace, pkg if node.replace?

parse = (source, rules, dir) ->
  pkg = undefined
  entry = undefined
  ast = parser.parse source
  # console.dir ast, depth: 20, colors: true
  _.each ast, (node) ->
    switch node.type
      when 'Include'
        include node.path, rules, dir
      when 'Package'
        pkg = node.name
      when 'Import'
        node.rules.forEach (name) ->
          importRule rules, name, node.from, pkg
      when 'Rule'
        name = pack node.name, pkg
        entry = name unless entry?
        setRule rules, name, node, pkg

  rules.$entry = entry

importRule = (rules, name, from, into) ->
  nameFrom = pack name, from
  nameInto = pack name, into
  args = rules[nameFrom].args
  if args?
    args = args.map (arg) ->
      packReplace arg, into
    argsCalls = args.map (arg) ->
      type: 'Call'
      name: arg
  imported =
    type: 'Rule'
    name: nameInto
    args: args
    expr:
      type: 'Call'
      name: nameFrom
      args: argsCalls
  rules[nameInto] = imported

setRule = (rules, name, rule, pkg) ->
  rule.name = name
  packDeep rule, pkg
  rules[name] = rule
