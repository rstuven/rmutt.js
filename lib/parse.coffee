_ = require 'lodash'
fs = require 'fs'
peg = require 'pegjs'
path = require 'path'

###
# parse
###
module.exports = (source) ->
  [rules, includes] = parse source
  doIncludes rules, includes
  rules

grammar = fs.readFileSync __dirname + '/rmutt.pegjs', 'utf8'
parser = peg.buildParser grammar

PACKAGE_SEPARATOR = '.'

parse = (source) ->
  ast = parser.parse source

  rules = {}
  includes = []
  @package = null

  setRule = (name, rule) ->
    rules[pack name] = rule
    packDeep rule

  pack = (name, pkg) =>
    pkg ?= @package
    if pkg? and name.indexOf(PACKAGE_SEPARATOR) is -1
      return pkg + PACKAGE_SEPARATOR + name
    name

  packDeep = (node) =>
    return unless @package?
    if node.type in ['RuleCall', 'Assignment']
      node.name = pack node.name
    else if node.items?
      for item in node.items
        packDeep item
    else if node.expr?
      packDeep node.expr

  _.each ast, (node) =>
    switch node.type
      when 'Include'
        includes.push node.path
      when 'Package'
        @package = node.name
      when 'Import'
        setRule node.rule, rules[pack node.rule, node.package]
      when 'Rule'
        setRule node.name, node

  [rules, includes]

doIncludes = (rules, includes, dir) ->
  _.each includes, (include) ->
    if dir
      fullpath = path.join dir, include
    else
      fullpath = path.join process.cwd(), include
    source = fs.readFileSync fullpath, 'utf8'
    [rules2, includes2] = parse source
    _.assign rules, rules2
    doIncludes rules, includes2, path.dirname(fullpath)
