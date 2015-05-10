_ = require 'lodash'
runtime = require './runtime'
parse = require './parse'
product = require '../package.json'
push = Array::push

###
# transpile
###
module.exports = (input, options, callback) ->
  if callback?
    options ?= {}
  else
    callback = options
    options = {}

  if typeof input is 'string'
    parse input, options, (err, rules) ->
      return callback err if err?
      transpile rules, options, callback
  else
    transpile input, options, callback

ROOT_SCOPE_VAR = '$root'
LOCAL_SCOPE_VAR = '$'

transpile = (rules, options, callback) ->
  # console.dir rules, colors: true, depth:10

  # detect composable external rules
  options.composable = []
  _.each options.externals, (fn, name) ->
    if fn.toString().indexOf('return function') isnt -1
      options.composable.push name

  result = []

  # header
  result.push '// Generated by ', product.name, ' ', product.version, '\n'
  result.push '// ', options.header, '\n' if options.header?

  # exportable
  result.push 'module.exports = function ($options, callback) {\n'

  # fallback
  result.push """
    if (callback == null) {
      callback = $options;
      $options = {};
    } else {
      $options = $options || {};
    }\n"""

  # runtime
  result.push 'var slice = Array.prototype.slice;\n'
  result.push runtime.toString().replace(/^function \(\) {/g, '').replace(/}$/g, '')
  result.push '\n\n'

  # root scope
  result.push 'var ', ROOT_SCOPE_VAR, ' = new $Scope();\n\n'
  _.each rules, (rule, name) ->
    return if name is '$entry'
    push.apply result, concat [
      generateRuleDefinition ROOT_SCOPE_VAR, rule, options
      '();\n\n'
    ]

  # kick off
  entry = options.entry ? rules.$entry
  result.push 'var result;\n'
  result.push 'try {\n'
  if entry?
    result.push 'result = '
    result.push ROOT_SCOPE_VAR
    result.push '.invoke($options.entry || "', entry, '")();\n'
  else
    result.push 'if ($options.entry != null) result = '
    result.push ROOT_SCOPE_VAR
    result.push '.invoke($options.entry)();\n'
  result.push '} catch (err) { return callback(err); }\n'
  result.push 'callback(null, result);\n'

  # done!
  result.push '};'

  # console.log result.join ''
  callback null, result.join ''

types =

  Assignment: (rule, options) ->
    generateAssignment LOCAL_SCOPE_VAR, rule, generateRule rule.expr, options

  Choice: (rule, options) ->

    # Simplify single choice
    if rule.items.length is 1 and rule.items[0].type isnt 'Multiplied'
      return generateRule rule.items[0], options

    choices = pushJoin ', ', rule.items.map (rule) ->
      return "''" if not rule?
      if rule.type is 'Multiplied'
        multiplied = Array rule.multiplier
        _.fill multiplied, generateRule rule.expr, options
        pushJoin ', ', multiplied
      else
        generateRule rule, options

    concat [
      '$choice('
      choices
      ')'
    ]

  Invocation: (rule, options) ->
    args = rule.args?
    concat [
      LOCAL_SCOPE_VAR
      '.invoke'
      if rule.prefix is '@' then 'Indirection'
      "('#{rule.name}'"
      if args then ', ['
      if args then generateRules rule.args, options
      if args then ']'
      ')'
    ]

  Multiplied: (rule, options) ->
    # Ignore rule.multiplier (parsed at this level for backward compatibility).
    # See it in action in Choice type.
    generateRule rule.expr, options

  Mapping: (rule, options) ->
    concat [
      '$mapping('
      generateRule rule.search, options
      ', '
      generateRule rule.replace, options
      ')'
    ]

  Repetition: (rule, options) ->
    concat [
      '$repeat('
      generateRule rule.expr, options
      ', '
      JSON.stringify rule.range
      ')'
    ]

  Rule: (rule, options) ->
    generateRuleDefinition LOCAL_SCOPE_VAR, rule, options

  Terms: (rule, options) ->

    # Simplify single term
    if rule.items.length is 1
      return generateRule rule.items[0], options

    isComposable = (item) ->
      return true if item.type is 'Mapping'
      return true if item.type is 'Invocation' and item.name in options.composable
      false

    fn = if _.all(rule.items, isComposable)
      '$compose'
    else
      '$concat'

    concat [
      fn
      '('
      generateRules rule.items, options
      ')'
    ]

  Transformation: (rule, options) ->
    # for transformation chaining, we need to make the tree left-recursive
    if rule.type is 'Transformation' and rule.func.type is 'Transformation'
      rule = makeTreeLeftRecursive rule, 'Transformation', 'expr', 'func'

    concat [
      '$transform('
      generateRule rule.expr, options
      ', '
      generateRule rule.func, options
      ')'
    ]

concat = (values) ->
  values.reduce (ret, value) ->
    ret.concat value
  , []

generateAssignment = (scope, rule, generated) ->
  concat [
    scope
    ".assign('#{rule.name}', "
    generated
    if rule.scope? then ", '#{rule.scope}'"
    ')'
  ]

generateRule = (rule, options) ->
  return '""' unless rule?
  return JSON.stringify rule if typeof rule is 'string'
  unless types[rule.type]?
    throw new Error 'No transpilation defined for rule type: ' + rule.type
  types[rule.type] rule, options

generateRuleDefinition = (scope, rule, options) ->
  concat [
    scope
    '.rule('
    JSON.stringify rule.name
    ', '
    JSON.stringify(rule.args ? [])
    ', function ('
    LOCAL_SCOPE_VAR
    ') {\nreturn '
    generateRule rule.expr, options
    ';\n}'
    if rule.scope? then ", '#{rule.scope}'"
    ')'
  ]

generateRules = (rules, options) ->
  pushJoin ', ', rules.map (rule) -> generateRule rule, options

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
