_ = require 'lodash'
jsStringEscape = require 'js-string-escape'
runtime = require './runtime'

###
# transpile
###
module.exports = (rules) ->
  # console.dir rules, colors: true, depth:10
  result = []

  # runtime
  _.each runtime, (util, name) ->
    result.push 'var $', name , ' = ', util.toString(), ';\n'

  # global scope
  result.push 'var $ = {};\n'
  _.each rules, (rule, name) ->
    result.push '$["', name, '"] = '
    [].push.apply result, ruleDef rule
    result.push ';\n'

  # kick off
  topRule = _.first _.keys rules
  result.push 'return $["', topRule, '"]();\n'

  result.join ''

# TODO: Study extensibility model (user function)
composable = ['Mapping', 'RxSub']

translations =

  # DEVNOTE: Ir alphabetical order

  Assignment: (rule) ->
    assignment rule, evalRule rule.expr

  Choice: (rule) ->
    []
    .concat '$choice('
    .concat evalRules rule.items
    .concat ')'

  Repetition: (rule) ->
    []
    .concat '$repeat('
    .concat evalRule rule.repeatable
    .concat ', '
    .concat JSON.stringify rule.range
    .concat ')'

  Rule: (rule) ->
    assignment rule, ruleDef rule

  RuleCall: (rule) ->
    res = [
      '$eval(s, "'
      rule.name
      '"'
    ]
    if rule.args?
      res = res
      .concat ', ['
      .concat evalRules rule.args
      .concat ']'
    res.push ')'
    res

  String: (rule) ->
    ['"', jsStringEscape(rule.value), '"']

  Terms: (rule) ->
    if _.all(rule.items, (item) -> item.type in composable)
      fn = '$compose'
    else
      fn = '$concat'

    [fn, '(']
    .concat evalRules rule.items
    .concat ')'

  Multiplier: (rule) ->
    res = []
    for i in [1 .. rule.multiplier] by 1
      res.push ',' if i > 1
      [].push.apply res, evalRule rule.term.items[0]
    res

  Mapping: (rule) ->
    []
    .concat '$mapping('
    .concat evalRule rule.search
    .concat ','
    .concat evalRule rule.replace
    .concat ')'

  # TODO: Generalize grammar to use Mapping type only
  RxSub: (rule) ->
    []
    .concat '$mapping("'
    .concat rule.search
    .concat '","'
    .concat rule.replace
    .concat '")'

  Transformation: (rule) ->

    # for transformation chaining, we need to make the tree left-recursive
    if rule.type is 'Transformation' and rule.func.type is 'Transformation'
      rule = makeTreeLeftRecursive rule, 'Transformation', 'expr', 'func'

    []
    .concat evalRule rule.func
    .concat '('
    .concat evalRule rule.expr
    .concat ')'

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
    when 'global' then 'g'
    else '^'
  [
    '$assign("'
    scope
    '", s, "'
    rule.name
    '", '
  ]
  .concat evalued
  .concat ')'

evalRule = (rule) ->
  throw new Error 'Unkown rule type: ' + rule.type unless translations[rule.type]?
  translations[rule.type] rule

evalRules = (rules) ->
  pushJoin ', ', rules.map (rule) -> evalRule rule

pushJoin = (join, array) ->
  res = []
  array.forEach (item, index) ->
    res.push join if index > 0
    [].push.apply res, item
  res

ruleDef = (rule) ->
  res = []
  .concat '$rule(function(s) { \nreturn '
  .concat evalRule rule.expr
  .concat ';\n}'
  res.push ', ', JSON.stringify rule.args if rule.args?
  res.push ')'
  res
