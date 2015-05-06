###
# runtime
###
module.exports =

  ###
  # @class $Scope
  ###
  Scope: -> class $Scope

    constructor: (@parent) ->
      @vars = {}
      if @parent?
        @root = @parent.root
        @vars[k] = v for k, v of @parent.vars
        @stackDepth = @parent.stackDepth + 1
      else
        @root = @
        @stackDepth = 1

    assign: (name, value, scope) ->
      if scope is 'root'
        @root.vars[name] = value
      else
        @vars[name] = value
        if @parent? and scope is 'parent'
          @parent.vars[name] = value
      return

    invokeLazy: (name, args) ->
      => @invoke name, args

    invoke: (name, args) ->

      return if $config.maxStackDepth? and @stackDepth >= $config.maxStackDepth

      get = (scope) =>
        ref = scope.vars[name]
        return [false] unless ref?
        return [true, ref(@, args)] if typeof ref is 'function'
        return [true, ref]

      # local
      [found, value] = get @
      return value if found

      # parent
      if @parent?
        [found, value] = get @parent
        return value if found

      # root
      [found, value] = get @root
      return value if found

      # external rule with arguments
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
  choice: ->  ->
    index = $choose arguments.length
    value = arguments[index]
    $unlazy value

  ###
  # $choose
  ###
  choose: -> (terms) ->
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
  compose: -> ->
    res = (v) -> v
    [].slice.apply(arguments)
      .forEach (fn) ->
        nonClosure = res
        res = (v) -> fn nonClosure v
    res

  ###
  # $concat
  ###
  concat: -> ->
    [].slice.apply(arguments)
      .filter (x) -> typeof x is 'string'
      .reduce ((a, b) -> a + b), ''

  ###
  # $mapping
  ###
  mapping: -> (search, replacement) ->
    (input) ->
      return unless input?
      return input unless replacement?
      input.replace new RegExp(search, 'g'), ->
        args = arguments
        $unlazy(replacement).replace /\\(\d+)/g, (m, n) -> args[n]

  ###
  # $repeat
  ###
  repeat: -> (value, range) ->
    max = range.min + $choose (range.max - range.min + 1)
    ($unlazy value for [1 .. max] by 1).join ''

  ###
  # $rule
  ###
  rule: -> (fn, argnames) ->
    (scope, args) ->
      scope = new $Scope scope
      if args?
        for arg, i in args
          # positional argument:
          scope.vars['_' + (i+1)] = arg
          # named argument:
          scope.vars[argnames[i]] = arg if argnames?
      fn scope

  ###
  # $transform
  ###
  transform: -> (expr, fn) ->
    unless typeof fn is 'function'
      # console.warn "Transform expression '#{fn?.toString()}' is not a function"
      return expr
    fn expr

  ###
  # $unlazy
  ###
  unlazy: -> (value) ->
    if typeof value is 'function'
      value()
    else
      value
