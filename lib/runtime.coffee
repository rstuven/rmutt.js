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
      local.vars[name] = value
      if scope is '^' and local.parent?
        local.parent.vars[name] = value
    return

  ###
  # $call
  ###
  call: (local, name, args) ->

    return if $config.maxStackDepth? and local.stackDepth > $config.maxStackDepth

    get = (vars) ->
      if vars?.hasOwnProperty name
        ref = vars[name]
        if typeof ref is 'function'
          return [true, ref(local, args)]
        else
          return [true, ref]
      [false]

    # local
    [found, value] = get local.vars
    return value if found

    # parent
    if local.parent?
      [found, value] = get local.parent.vars
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
      return unless input?
      return input unless replace?
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
          s.vars['_' + (i+1)] = arg
          # named argument:
          s.vars[argnames[i]] = arg if argnames?
      fn s

  ###
  # $scope
  ###
  scope: (parent) ->

    local =
      vars: {}
      call: (name, args) ->
        $call local, name, args
      callfn: (name, args) ->
        -> $call local, name, args

    if parent?
      for k, v of parent.vars
        local.vars[k] = v
      local.parent = parent
      local.stackDepth = parent.stackDepth + 1
    else
      local.stackDepth = 1

    local

  ###
  # $transform
  ###
  transform: (expr, fn) ->
    unless typeof fn is 'function'
      # console.warn "Transform expression '#{fn?.toString()}' is not a function"
      return expr
    fn expr
