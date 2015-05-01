_ = require 'lodash'
fs = require 'fs'
peg = require 'pegjs'
path = require 'path'

PACKAGE_SEPARATOR = '.'

grammar = fs.readFileSync __dirname + '/rmutt.pegjs', 'utf8'
parser = peg.buildParser grammar

###
# parse
###
module.exports = (source, config) ->
  rules = {}
  parse source, rules, config?.workingDirectory
  # console.dir rules, depth:10
  rules

include = (file, rules, dir) ->
  fullpath = path.join (dir ? process.cwd()), file
  source = fs.readFileSync fullpath, 'utf8'
  parse source, rules, path.dirname fullpath

pack = (name, pkg) ->
  if pkg? and name.indexOf(PACKAGE_SEPARATOR) is -1
    return pkg + PACKAGE_SEPARATOR + name
  name

packDeep = (node, pkg) ->
  return unless pkg?

  if node.type in ['RuleCall', 'Assignment']
    node.name = pack node.name, pkg

  if node.items?
    for item in node.items
      packDeep item, pkg

  if node.type is 'Rule' and node.args?
    node.args.forEach (arg, i) ->
      node.args[i] = pack arg, pkg

  packDeep node.expr, pkg if node.expr?
  packDeep node.func, pkg if node.func?

parse = (source, rules, dir) ->
  pkg = undefined
  top = undefined
  ast = parser.parse source
  _.each ast, (node) ->
    switch node.type
      when 'Include'
        include node.path, rules, dir
      when 'Package'
        pkg = node.name
      when 'Import'
        name = pack node.rule, pkg
        rule = rules[pack node.rule, node.package]
        setRule rules, name, rule, pkg
      when 'Rule'
        name = pack node.name, pkg
        top = name unless top?
        setRule rules, name, node, pkg

  rules.$top = top

setRule = (rules, name, rule, pkg) ->
  rules[name] = rule
  packDeep rule, pkg
