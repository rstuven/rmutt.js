###
# runtime
###
module.exports =

  # DEVNOTE: Ir alphabetical order

  ###
  # $assign
  ###
  assign: (scope, s, name, value) ->
    if scope is 'g'
      $[name] = value
    else
      s[name] = value
      if scope is '^'
        s.$outer[name] = value
    return

  ###
  # $choice
  ###
  choice: ->
    index = $choose arguments.length
    arguments[index]() # lazy rule evaluation

  ###
  # $choose
  ###
  choose: (terms) ->
    if $config.oracle?
      $config.terms = terms
      index = $config.oracle % terms
      $config.oracle = Math.floor $config.oracle / terms
    else
      index = Math.floor terms * Math.random()

    index

  ###
  # $compose
  ###
  compose: ->
    res = (v) -> v
    [].slice.apply(arguments)
      .forEach (fn) ->
        nonClosure = res
        res = (v) -> fn nonClosure v
    res

  ###
  # $concat
  ###
  concat: ->
    [].slice.apply(arguments)
      .filter (x) -> typeof x is 'string'
      .reduce ((a, b) -> a + b), ''

  ###
  # $eval
  ###
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

    # custom function as parameterized rule
    if $config.functions?[name]? and args?
      return $config.functions[name].apply null, (args)

    if args?
      throw new Error "Missing parameterized rule or custom function '#{name}'"

    # custom function as transformation, probably
    if $config.functions?[name]?
      return $config.functions[name]

    return name

  ###
  # $func
  ###
  func: (fn) ->
    return fn if typeof fn is 'function'
    throw new Error "Processing grammar: expression '#{fn.toString()}' is not a function"

  ###
  # $mapping
  ###
  mapping: (search, replace) ->
    (input) ->
      input.replace new RegExp(search, 'g'), replace

  ###
  # $repeat
  ###
  repeat: (value, range) ->
    max = range.min + $choose (range.max - range.min + 1)
    Array(max + 1).join value

  ###
  # $rule
  ###
  rule: (fn, argnames) ->
    (s, args) ->
      s = $scope s
      if args?
        for arg, i in args
          s['_' + (i+1)] = arg # positional argument
          s[argnames[i]] = arg # named argument
      fn s

  ###
  # $scope
  ###
  scope: (outer) ->
    local = {}
    if outer?
      for k, v of outer
        local[k] = v
    local.$outer = outer
    local
