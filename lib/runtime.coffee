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
      if scope is '^'
        s.$outer[name] = value
      s[name] = value

    return undefined

  ###
  # $choice
  ###
  choice: ->
    index = $choose arguments.length
    arguments[index]

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

    return name

  ###
  # $mapping
  ###
  mapping: (search, replace) ->
    (text) ->
      text.replace new RegExp(search, 'g'), replace

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
          s['_' + (i+1)] = arg
          s[argnames[i]] = arg
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
