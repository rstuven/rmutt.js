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
      $global[name] = value
    else
      s[name] = value
      if scope is '^'
        s.$parent[name] = value
    return

  ###
  # $choice
  ###
  choice: ->
    index = $choose arguments.length
    value = arguments[index]
    value?() ? value # lazy rule evaluation

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
  eval: (local, name, args) ->

    get = (scope) ->
      if scope?.hasOwnProperty name
        ref = scope[name]
        if typeof ref is 'function'
          return [true, ref(local, args)]
        else
          return [true, ref]
      [false]

    # local
    [found, value] = get local
    return value if found

    # parent
    [found, value] = get local.$parent
    return value if found

    # global
    [found, value] = get $global
    return value if found

    # custom function as parameterized rule
    if args? and $config.functions?[name]?
      return $config.functions[name].apply null, args

    # orphan args :(
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
  scope: (parent) ->
    local = {}
    if parent?
      for k, v of parent
        local[k] = v
    local.$parent = parent
    local
