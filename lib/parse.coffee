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

parse = (source) ->
  ast = parser.parse source

  rules = {}
  includes = []
  currentPackage = null

  setRule = (name, rule) ->
    if currentPackage?
      name = currentPackage + '.' + name

    rules[name] = rule
    recursiveNamespacing rule

  recursiveNamespacing = (rule) ->
    return unless currentPackage?
    if rule.type in ['RuleCall', 'Assignment']
      if rule.name.indexOf('.') is -1
        rule.name = currentPackage + '.' + rule.name
    else if rule.items?
      for item in rule.items
        recursiveNamespacing item
    else if rule.expr?
      recursiveNamespacing rule.expr

  _.each ast, (r) ->
    switch r.type
      when 'Include'
        includes.push r.path
      when 'Package'
        currentPackage = r.name
      when 'Import'
        setRule r.rule, rules[r.package + '.' + r.rule]
      when 'Rule'
        setRule r.name, r

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
