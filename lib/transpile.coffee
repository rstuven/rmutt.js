_ = require 'lodash'
jsStringEscape = require 'js-string-escape'
runtime = require './runtime'
push = Array.prototype.push

###
# transpile
###
module.exports = (rules) ->
  result = transpile rules
  # console.log result
  result

transpile = (rules) ->
  # console.dir rules, colors: true, depth:10
  result = []

  result.push 'module.exports = function($config) {\n'

  # fallback
  result.push '$config = $config || {};\n'

  # runtime
  _.each runtime, (fn, name) ->
    result.push 'var $', name , ' = ', fn.toString(), ';\n'

  # global scope
  result.push 'var $global = {};\n\n'
  _.each rules, (rule, name) ->
    return if name is '$top'
    push.apply result, concat [
      "$global['#{name}'] = "
      ruleDef rule
      ';\n\n'
    ]

  # kick off
  # TODO: entry point configuration
  topRule = rules.$top
  if topRule?
    result.push "return $global['#{topRule}']();\n"

  # module.exports = ... {
  result.push '};'

  result.join ''

# TODO: Study extensibility model (user function)
composable = ['Mapping']

types =

  # DEVNOTE: In alphabetical order

  Assignment: (rule) ->
    assignment rule, evalRule rule.expr

  Choice: (rule) ->

    # Simplify single choice
    if rule.items.length is 1
      return evalRule rule.items[0]

    lazyRules = pushJoin ', ', rule.items.map (rule) ->
      return "''" if not rule?
      evalued = evalRule rule
      if typeof evalued is 'string'
        evalued
      else
        concat [
          'function(){ return '
          evalued
          '}'
        ]

    concat [
      '$choice('
      lazyRules
      ')'
    ]

  Repetition: (rule) ->
    concat [
      '$repeat('
      'function(){ return '
      evalRule rule.expr
      '}'
      ', '
      JSON.stringify rule.range
      ')'
    ]

  Rule: (rule) ->
    assignment rule, ruleDef rule

  Call: (rule) ->
    args = (v) -> v() if rule.args?
    concat [
      "$call(s, '#{rule.name}'"
      args -> ', ['
      args -> evalRules rule.args
      args -> ']'
      ')'
    ]

  String: (rule) ->
    "'#{jsStringEscape rule.value}'"

  Terms: (rule) ->

    # Simplify single term
    if rule.items.length is 1
      return evalRule rule.items[0]

    fn =  if _.all(rule.items, (item) -> item.type in composable)
      '$compose'
    else
      '$concat'
    concat [
      fn
      '('
      evalRules rule.items
      ')'
    ]

  Multiplier: (rule) ->
    array = Array rule.multiplier
    item = evalRule rule.term.items?[0] ? rule.term
    _.fill array, item
    pushJoin ', ', array

  Mapping: (rule) ->
    concat [
      '$mapping('
      evalRule rule.search
      ','
      evalRule rule.replace
      ')'
    ]

  Transformation: (rule) ->
    # for transformation chaining, we need to make the tree left-recursive
    if rule.type is 'Transformation' and rule.func.type is 'Transformation'
      rule = makeTreeLeftRecursive rule, 'Transformation', 'expr', 'func'

    concat [
      '$func('
      evalRule rule.func
      ')('
      evalRule rule.expr
      ')'
    ]

###
Convert a right-recursive tree to a left-recursive tree.

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
    flipped = type: type
    if node.type is type
      fifo.push node[left]
      flipped[left] = makeTreeLeftRecursive node[right], type, left, right, fifo
      flipped[right] = fifo.shift()
    else
      flipped[left] = fifo.shift()
      flipped[right] = fifo.shift()
      fifo.push node
    flipped
  else
    makeTreeLeftRecursive node[right], type, left, right, [node[left]]

assignment = (rule, evalued) ->
  scope = switch rule.scope
    when 'local' then 'l'
    when 'parent' then '^'
    else 'g'

  concat [
    "$assign('#{scope}', s, '#{rule.name}', "
    evalued
    ')'
  ]

concat = (values) ->
  values.reduce (ret, value) ->
    ret.concat value
  , []

evalRule = (rule) ->
  return types.String value: rule if typeof rule is 'string'
  unless types[rule.type]?
    throw new Error 'No transpilation defined for rule type: ' + rule.type
  types[rule.type] rule

evalRules = (rules) ->
  pushJoin ', ', rules.map (rule) -> evalRule rule

pushJoin = (join, array) ->
  ret = []
  array.forEach (item, index) ->
    return unless item?
    ret.push join if index > 0
    if item instanceof Array
      push.apply ret, item
    else
      ret.push item
  ret

ruleDef = (rule) ->
  concat [
    '$rule(function rule_'
    rule.name.replace /[.-]/g, '_'
    '(s) { \n'
    'return '
    evalRule rule.expr
    ';\n}'
    if rule.args? then ', ' + JSON.stringify rule.args
    ')'
  ]
