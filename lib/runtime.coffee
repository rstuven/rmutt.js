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
      => # lazy
        uvalue = $unlazy value
        if scope is 'root'
          @root.vars[name] = uvalue
        else
          @vars[name] = uvalue
          if @parent? and scope is 'parent'
            @parent.vars[name] = uvalue
        return

    invoke: (name, args) ->
      =>  # lazy

        return if $config.maxStackDepth? and @stackDepth >= $config.maxStackDepth

        uargs = -> args.map $unlazy if args?

        get = (scope) =>
          ref = scope.vars[name]
          return [false] unless ref?
          return [true, $unlazy ref(@, uargs())] if ref.$isRule
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
          return $config.externals[name].apply null, uargs()

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
  choice: -> ->
    args = [].slice.apply arguments
    -> # lazy
      index = $choose args.length
      value = args[index]
      $unlazy value

  ###
  # $choose
  ###
  choose: -> (terms) ->
    if $config.iteration?
      $config.terms = terms
      index = $config.iteration % terms
      $config.iteration = Math.floor $config.iteration / terms
    else
      index = Math.floor terms * Math.random()
    index

  ###
  # $compose
  ###
  compose: -> ->
    args = [].slice.apply arguments
    -> # lazy
      res = (v) -> v
      args
        .forEach (fn) ->
          nonClosure = res
          res = (v) -> ($unlazy fn)(nonClosure(v))
      res

  ###
  # $concat
  ###
  concat: -> ->
    args = [].slice.apply arguments
    -> # lazy
      args
        .map (x) -> $unlazy x
        .filter (x) -> typeof x is 'string'
        .reduce ((a, b) -> a + b), ''

  ###
  # $mapping
  ###
  mapping: -> (search, replacement) ->
    -> # lazy
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
    -> # lazy
      max = range.min + $choose (range.max - range.min + 1)
      ($unlazy value for [1 .. max] by 1).join ''

  ###
  # $rule
  ###
  rule: -> (fn, argnames) ->
    rule = (scope, args) ->
      scope = new $Scope scope
      if args?
        for arg, i in args
          # positional argument:
          scope.vars['_' + (i+1)] = arg
          # named argument:
          scope.vars[argnames[i]] = arg if argnames?
      fn scope
    rule.$isRule = true
    rule

  ###
  # $transform
  ###
  transform: -> (expr, fn) ->
    -> # lazy
      ufn = $unlazy fn
      uexpr = $unlazy expr
      unless typeof ufn is 'function'
        # console.warn "Transform expression '#{fn?.toString()}' is not a function"
        return uexpr
      ufn uexpr

  ###
  # $unlazy
  ###
  unlazy: -> (value) ->
    if typeof value is 'function' and not value.$isRule
      value()
    else
      value
