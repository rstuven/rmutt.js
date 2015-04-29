_ = require 'lodash'
fs = require 'fs'
peg = require 'pegjs'
path = require 'path'
jsStringEscape = require 'js-string-escape'

grammar = fs.readFileSync __dirname + '/rmutt.pegjs', 'utf8'
parser = peg.buildParser grammar

exports.parse = (source) ->
  [rules, includes] = parse source
  doIncludes rules, includes
  compile rules

exports.generate = (source, config) ->
  config ?= {}

  if typeof source is 'string'
    compiled = exports.parse source
  else
    compiled = [].slice.apply source

  compiled.push '$config = ', JSON.stringify(config), ';\n'
  compiled.push '$main();\n'
  output = eval compiled.join ''
  output


compile = (rules) ->
  # console.dir rules, colors: true, depth:10

  pushJoin = (res, join, array) ->
    array.forEach (item, index) ->
      res.push join if index > 0
      [].push.apply res, item
    res

  runtime =

    eval: (s, name, args) ->

      # local
      if s.hasOwnProperty name
        ref = s[name]
        if typeof ref is 'function'
          return ref s, args
        else
          return ref

      # outer
      if s.$outer?.hasOwnProperty name
        ref = s.$outer[name]
        if typeof ref is 'function'
          return ref s, args
        else
          return ref

      # global
      if $.hasOwnProperty name
        ref = $[name]
        if typeof ref is 'function'
          return ref s, args
        else
          return ref

      return name

    choose: (terms) ->
      if $config.index? and not $config.len?
        index = $config.index % terms
      else if $config.index? and $config.len?
        $config.bc ?= Math.pow(2, $config.len) - 1
        $config.fac ?= 1 + parseInt($config.index / ($config.bc+1))
        $config.res ?= $config.bc - ($config.index % ($config.bc + 1) )
        $config.x ?= 0
        x = $config.fac * ( (($config.bc - $config.res) % 2))
        $config.res = parseInt($config.res / 2)
        index = x % terms
        $config.x++
        if ($config.x % $config.bc) is 0
          $config.res = null
      else
        index = parseInt(terms * Math.random())

      index

    choice: ->
      index = $choose arguments.length
      arguments[index]

    concat: ->
      [].slice.apply(arguments)
        .filter (x) -> typeof x is 'string'
        .reduce ((a, b) -> a + b), ''

    assign: (scope, s, name, value) ->
      if scope is 'g'
        $[name] = value
      else
        if scope is '^'
          s.$outer[name] = value
        s[name] = value

      return undefined

    scope: (outer) ->
      local = {}
      if outer?
        for k, v of outer
          local[k] = v
      local.$outer = outer
      local

    rule: (fn, argnames) ->
      (s, args) ->
        s = $scope s
        if args?
          for arg, i in args
            s['_' + (i+1)] = arg
            s[argnames[i]] = arg
        fn s

    repeat: (value, range) ->
      max = range.min + $choose (range.max - range.min + 1)
      Array(max + 1).join value

    mapping: (search, replace) ->
      (text) ->
        text.replace new RegExp(search, 'g'), replace

    compose: ->
      res = (v) -> v
      [].slice.apply(arguments)
        .forEach (fn) ->
          nonClosure = res
          res = (v) -> fn nonClosure v
      res

  composable = ['Mapping', 'RxSub']

  evals =

    String: (rule) ->
      ['"', jsStringEscape(rule.value), '"']

    Terms: (rule) ->
      if _.all(rule.items, (item) -> item.type in composable)
        fn = '$compose'
      else
        fn = '$concat'

      pushJoin([fn, '('], ', ', rule.items.map (item) ->
        evalRule item
      ).concat(')')

    Choice: (rule) ->
      res = []
      res.push '$choice('
      pushJoin res, ', ', rule.items.map (item) ->
        evalRule item
      res.push ')'
      res

    RuleCall: (rule) ->
      res = ['$eval(s, "', rule.name, '"']
      if rule.args?
        res.push ', ['
        rule.args.forEach (arg, i) ->
          res.push ', ' if i > 0
          [].push.apply res, evalRule arg
        res.push ']'
      res.push ')'
      res

    Assignment: (rule) ->
      scope = switch rule.scope
        when 'local' then 'l'
        when 'global' then 'g'
        else '^'
      ['$assign("', scope, '", s, "', rule.name, '", ']
        .concat(evalRule rule.expr)
        .concat(')')

    Rule: (rule) ->
      scope = switch rule.scope
        when 'local' then 'l'
        when 'global' then 'g'
        else '^'
      res = [
        '$assign("'
        scope
        '", s, "'
        rule.name
        '", $rule(function(s) { \nreturn '
      ]
      [].push.apply res, evalRule rule.expr
      res.push ';}'
      res.push ', ', JSON.stringify rule.args if rule.args?
      res.push '))'
      res

    Repetition: (rule) ->
      []
      .concat '$repeat('
      .concat evalRule rule.repeatable
      .concat ', '
      .concat JSON.stringify rule.range
      .concat ')'

    Multiplier: (rule) ->
      res = []
      for i in [1 .. rule.multiplier] by 1
        res.push ',' if i > 1
        [].push.apply res, evalRule rule.term.items[0]
      res

    Transformation: (rule) ->

      # for transformation chaining, we need to make the tree left-recursive
      if rule.type is 'Transformation' and rule.func.type is 'Transformation'
        rule = makeTreeLeftRecursive rule, 'Transformation', 'expr', 'func'

      []
      .concat evalRule rule.func
      .concat '('
      .concat evalRule rule.expr
      .concat ')'

    Mapping: (rule) ->
      []
      .concat '$mapping('
      .concat evalRule rule.search
      .concat ','
      .concat evalRule rule.replace
      .concat ')'

    RxSub: (rule) ->
      []
      .concat '$mapping("'
      .concat rule.search
      .concat '","'
      .concat rule.replace
      .concat '")'

  evalRule = (rule) ->
    # console.log 'evalRule'
    # console.dir rule, colors: true, depth: 10
    if typeof rule is 'string'
      ruleName = rule
      rule = rules[ruleName]

    if evals[rule.type]?
      evals[rule.type] rule
    else
      throw new Error 'Unkown rule type: ' + rule.type


  result = []

  # runtime
  _.each runtime, (util, name) ->
    result.push '$', name , ' = ', util.toString(), ';\n'

  # global scope
  result.push '$ = {};\n'
  _.each rules, (rule, name) ->
    result.push '$["', name, '"] = $rule(function(s) {\n  return '
    [].push.apply result, evalRule rule.expr
    result.push '; }'
    if rule.args?
      result.push ','
      result.push JSON.stringify rule.args
    result.push ');\n'

  # kick off
  topRule = _.first _.keys rules
  result.push '$main = $["', topRule, '"];\n'

  result

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
