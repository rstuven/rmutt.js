###
# runtime
###
module.exports =

  # DEVNOTE: Ir alphabetical order

  ###
  # $assign
  ###
  assign: (scope, local, name, value) ->
    if scope is 'g'
      $global[name] = value
    else
      local[name] = value
      if scope is '^'
        local.$parent[name] = value
    return

  ###
  # $call
  ###
  call: (local, name, args) ->

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

    # external parameterized rule
    if args? and $config.externals?[name]?
      return $config.externals[name].apply null, args

    # orphan args :(
    if args?
      throw new Error "Missing parameterized rule '#{name}'"

    # external rule (used as transformation, probably)
    if $config.externals?[name]?
      return $config.externals[name]

    return name

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
  # $mapping
  ###
  mapping: (search, replace) ->
    (input) ->
      input.replace new RegExp(search, 'g'), ->
        args = arguments
        (replace?() ? replace).replace /\\(\d+)/g, (m, n) -> args[n]

  ###
  # $repeat
  ###
  repeat: (value, range) ->
    max = range.min + $choose (range.max - range.min + 1)
    (value?() ? value for [1 .. max] by 1).join ''

  ###
  # $rule
  ###
  rule: (fn, argnames) ->
    (s, args) ->
      s = $scope s
      if args?
        for arg, i in args
          # positional argument:
          s['_' + (i+1)] = arg
          # named argument:
          s[argnames[i]] = arg if argnames?
      fn s

  ###
  # $scope
  ###
  scope: (parent) ->
    local = {}
    if parent?
      for k, v of parent
        local[k] = v
    local.$parent = parent if parent?
    local.call = (name, args) ->
      $call local, name, args
    local.callfn = (name, args) ->
      -> $call local, name, args
    local

  ###
  # $transform
  ###
  transform: (expr, fn) ->
    unless typeof fn is 'function'
      throw new Error "Processing grammar: expression '#{fn?.toString()}' is not a function"
    fn expr
