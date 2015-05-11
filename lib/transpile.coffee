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

isTransformation = (code) ->
  # just a good guess...
  code.indexOf('return function') isnt -1

transpile = (rules, options, callback) ->
  # console.dir rules, colors: true, depth:10
  try
    options = _.clone options
    options.composable = detectComposableRules rules, options

    result = concat [
      'Header'
      'ModuleBegin'
      'GeneralRuntime'
      'RulesDefinitions'
      'EntryInvocation'
      'ModuleEnd'
    ].map (section) -> sections[section] rules, options

  catch err
    return callback err

  # console.log result.join ''
  callback null,
    transpiled: result.join ''
    options: options

detectComposableRules = (rules, options) ->
  result = []
  _.each options.externals, (fn, name) ->
    if isTransformation fn.toString()
      result.push name
  _.each rules, (rule, name) ->
    if rule.expr?.type is 'CodeBlock' and isTransformation rule.expr.code
      result.push name
  result

sections =

  Header: (rules, options) ->
    concat [
      '// Generated by ', product.name, ' ', product.version, '\n'
      if options.header? then '// ' + options.header + '\n'
    ]

  ModuleBegin: (rules, options) ->
    """
    module.exports = function ($options, callback) {
      if (callback == null) {
        callback = $options;
        $options = {};
      } else {
        $options = (function(source){
          var target = {};
          for (var key in source) {
            target[key] = source[key];
          }
          return target;
        })($options || {});
      }
    \n
    """

  ModuleEnd: (rules, options) ->
    '};\n'

  GeneralRuntime: (rules, options) ->
    concat [
      'var slice = Array.prototype.slice;\n'
      runtime.toString().replace(/^function \(\) {/g, '').replace(/}$/g, '')
      '\n\n'
    ]

  RulesDefinitions: (rules, options) ->
    result = []
    result.push 'var ', ROOT_SCOPE_VAR, ' = new $Scope();\n\n'
    _.each rules, (rule, name) ->
      return if name is '$entry'
      push.apply result, concat [
        generateRuleDefinition ROOT_SCOPE_VAR, rule, options
        '();\n\n'
      ]
    result

  EntryInvocation: (rules, options) ->
    entry = options.entry ? rules.$entry
    concat [
      'var result;\n'
      'try {\n'
      if entry? then concat [
        'result = '
        ROOT_SCOPE_VAR
        '.invoke($options.entry || "', entry, '")();\n'
      ]
      else concat [
        'if ($options.entry != null) result = '
        ROOT_SCOPE_VAR
        '.invoke($options.entry)();\n'
      ]
      '} catch (err) { return callback(err); }\n'
      '\n'
      'callback(null, { generated: result, options: $options });\n'
    ]

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

  CodeBlock: (rule, options) ->
    concat [
      LOCAL_SCOPE_VAR
      '.evaluate('
      JSON.stringify rule.code
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
      return true if item.type is 'CodeBlock' and isTransformation item.code
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
