_ = require 'lodash'
fs = require 'fs'
peg = require 'pegjs'
path = require 'path'

grammar = fs.readFileSync __dirname + '/rmutt.pegjs', 'utf8'
parser = peg.buildParser grammar

exports.parse = (source) ->
  [rules, includes] = parse source
  doIncludes rules, includes
  rules

exports.generate = (source, config) ->

  config ?= {}

  if typeof source is 'string'
    rules = exports.parse source
  else
    rules = source

  console.log JSON.stringify rules, null, '  ' if config.logRules

  topRule = _.first _.keys rules

  choose = (terms) ->
    if config.index?
      index = config.index % terms
      config.index = parseInt(config.index / terms)
    else
      index = parseInt(Math.random() * terms)
    index

  variables = {}

  # rule evaluations by expression type
  evals =

    Rule: (rule) ->
      rules[rule.name] = rule.expr
      rule.expr.context = {}
      rule.expr.context.__parent = rule.context
      setContext rule.expr, rule.expr.context
      return

    Assignment: (rule) ->
      #console.log JSON.stringify rule
      if rule.scope is 'local'
        rule.context[rule.name] = evalRule rule.expr
      else
        ns = variables[rule.currentPackage ? ''] ?= {}
        ns[rule.name] = evalRule rule.expr
      return

    Terms: (rule) ->
      array = rule.items
      result = []
      _.each array, (rule) ->
        evalued = evalRule rule
        result.push evalued if evalued?
      result.join ''

    Repetition: (rule) ->
      range = rule.range
      max = range.min + choose (range.max - range.min + 1)
      result = []
      for i in [1 .. max] by 1
        result.push evalRule rule.repeatable
      result.join ''

    Choice: (rule) ->
      items = []
      _.each rule.items, (rule) ->
        if rule.type is 'Multiplier'
          multiplied = [1..rule.multiplier].map ->
            rule.term
          items = items.concat multiplied
        else
          items.push rule

      index = choose items.length
      evalRule items[index]

    Transformation: (rule) ->
      # transformation chaining requires we make the tree left-recursive
      if rule.type is 'Transformation' and rule.func.type is 'Transformation'
        rule = makeTreeLeftRecursive rule, 'Transformation', 'expr', 'func'

      expr = evalRule rule.expr

      # evaluate intermediate
      func = evalRule rule.func, true

      if func.type is 'Terms'
        func.type = 'Transformations'
      func = evalRule func

      func expr

    Transformations: (rule) ->
      (value) ->
        _.each rule.items, (item) ->
          value = evalRule(item)(value)
        value

    Mapping: (rule) ->
      (value) ->
        search = new RegExp(evalRule(rule.search), 'g')
        # eval replace rule only if we have a shot
        if search.test value
          replace = evalRule rule.replace
          search.lastIndex = 0
          value = value.replace search, replace
        value

    RxSub: (rule) ->
      (value) ->
        search = new RegExp(rule.search, 'g')
        value.replace search, rule.replace

  evalRule = (rule, intermediate) ->
    #console.log 'RULE:', JSON.stringify rule, null, '  '
    if typeof rule is 'string'
      ruleName = rule
      rule = rules[ruleName]

    if rule.type is 'String'
      rule.value
    else if rule.type is 'RuleCall'
      ruleName = rule.name
      xrule = rules[ruleName]
      if xrule?
        evalRule xrule, intermediate
      else # variable!
        local = rule.context[ruleName]
        global = variables[rule.currentPackage ? '']?[ruleName]
        #console.log JSON.stringify(s:rule.scope, sn:ruleName, l:local, g:global)
        return local ? global ? ruleName
    else if intermediate
      rule
    else
      evals[rule.type] rule if rule.type?

  evalRule topRule

parse = (source) ->
  ast = parser.parse source

  rules = {}
  includes = []
  currentPackage = null

  setRule = (name, rule) ->
    if currentPackage?
      name = currentPackage + '.' + name
      setPackage rule, currentPackage

    rules[name] = rule

    rule.currentPackage = currentPackage
    rule.context = {}
    setContext rule, rule.context

  _.each ast, (r) ->
    switch r.type
      when 'Include'
        includes.push r.path
      when 'Package'
        currentPackage = r.name
      when 'Import'
        setRule r.rule, rules[r.package + '.' + r.rule]
      when 'Rule'
        setRule r.name, r.expr

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

setPackage = (rule, packageName) ->
  return unless rule?
  if rule instanceof Array
    for e in rule
      setPackage e, packageName
  else if typeof rule is 'object'
    if rule.type in ['RuleCall', 'Assignment']
      if rule.name.indexOf('.') is -1
        rule.name = packageName + '.' + rule.name
    else if rule.items?
      setPackage rule.items, packageName
    else if rule.expr?
      setPackage rule.expr, packageName

setContext = (rule, context) ->
  return unless rule?
  if rule instanceof Array
    for e in rule
      setContext e, context
  else if typeof rule is 'object'
    if rule.items?
      setContext rule.items, context
    else if rule.expr?
      setContext rule.expr, context
    else if rule.func?
      setContext rule.func, context

    rule.context = context

###
Converts a right-recursive tree to a left-recursive tree.

(node1 (node2 (node3 node4))) => (((node1 node2) node3) node4)

type: type                  type: type
left: node1                 left:
right:                        type: type
  type: type                  left:
  left: node2        =>         type: type
  right:                        left: node1
    type: type                  right: node2
    left: node3               right: node3
    right: node4            right: node4

###
makeTreeLeftRecursive = (node, type, left, right, fifo) ->
  if fifo?
    o = type: type
    if node.type is type
      fifo.push node[left]
      o[left] = makeTreeLeftRecursive node[right], type, left, right, fifo
      o[right] = fifo.shift()
    else
      o[left] = fifo.shift()
      o[right] = fifo.shift()
      fifo.push node
    o
  else
    makeTreeLeftRecursive node[right], type, left, right, [node[left]]
