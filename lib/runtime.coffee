###
# runtime
###
module.exports = ->

  class $Scope

    constructor: (@parent) ->
      @vars = {}
      if @parent?
        @root = @parent.root
        @vars[k] = v for k, v of @parent.vars
        @stackDepth = @parent.stackDepth + 1
      else
        @root = @
        @stackDepth = 1

    rule: (name, argnames, expandible, scope) ->
      ruleAssignExpand = =>
        invocation = (parent, args) ->
          local = new $Scope parent
          local.package = name.split('.')[0] if name.indexOf('.') isnt -1
          if args?
            for arg, i in args
              # positional argument:
              local.vars['_' + (i+1)] = arg
              # named argument:
              local.vars[argnames[i]] = arg if argnames.length > 0
          localInvoke = (name, args) ->
            local.invoke name, args
          Object.keys($Scope::).forEach (k) ->
            v = local[k]
            return unless typeof v is 'function'
            localInvoke[k] = v.bind local
          expandible localInvoke
        invocation.$name = name
        invocation.displayName = 'invocation: ' + name
        @assignInternal name, invocation, scope

    assign: (name, value, scope) ->
      assignExpand = =>
        @assignInternal name, expand(value), scope

    assignInternal: (name, value, scope) ->
      if scope is 'root'
        @root.vars[name] = value
      else
        @vars[name] = value
        if @parent? and scope is 'parent'
          @parent.vars[name] = value
      return

    CodeBlock = (args, code) ->
      Function.apply @, args.concat(code)

    evaluate: (code) ->
      evaluateExpand = =>
        args = Object.keys @vars
        values = args.map (v) => @vars[v]
        if @package?
          args = args.map (v) => v.replace @package + '.', ''
        fn = new CodeBlock args, code
        result = fn.apply null, values
        return result if typeof result is 'function'
        (result ? '').toString()

    invokeRule: (invocation, args) ->

      try
        invoked = invocation @, args?.map expand
      catch err
        # displayName is not recognized by node.js :(
        err.message += '\n    at rule ' + invocation.displayName
        throw err

      ruleExpand = -> expand invoked
      ruleExpand.displayName = 'expansion: ' + invocation.$name

      try
        return ruleExpand()
      catch err
        # displayName is not recognized by node.js :(
        err.message += '\n    at rule ' + ruleExpand.displayName
        throw err

    invokeIndirection: (name, args) ->
      invokeIndirectionExpand = =>
        value = @invoke(name, args)()
        @invoke(value, args)()

    invoke: (name, args) ->
      invokeExpand = =>
        return if @stackDepth >= $options.maxStackDepth

        tryScope = (scope) =>
          ref = scope.vars[name]
          return [false] unless ref?
          return [true, @invokeRule(ref, args)] if typeof ref is 'function'
          return [true, ref]

        # local
        [found, value] = tryScope @
        return value if found

        # parent
        if @parent?
          [found, value] = tryScope @parent
          return value if found

        # root
        [found, value] = tryScope @root
        return value if found

        # external rule with arguments
        if args? and $options.externals?[name]?
          return $options.externals[name].apply null, args?.map expand

        # orphan args :(
        if args?
          throw new Error "Missing parameterized rule '#{name}'"

        # external rule (maybe used as variable or transformation)
        if $options.externals?[name]?
          return $options.externals[name]

        # $options virtual package
        if name.indexOf('$options.') is 0
          return ($options[name.split('.')[1]] ? '').toString()

        return name

  choice = (args...) ->
    choiceExpand = ->
      index = choose args.length
      value = args[index]
      expand value

  choose = (terms) ->
    if $options.iteration?
      index = $options.iteration % terms
      $options.iteration = Math.floor $options.iteration / terms
    else
      index = $random.integer 0, terms - 1
    index

  compose = (args...) ->
    composeExpand = ->
      res = (v) -> v
      args
        .forEach (fn) ->
          nonClosure = res
          res = (v) -> (expand fn)(nonClosure(v))
      res

  concat = (args...) ->
    concatExpand = ->
      args
        .map expand
        .filter (x) -> typeof x is 'string'
        .reduce ((a, b) -> a + b), ''

  expand = (value) ->
    if typeof value is 'function'
      value()
    else
      value

  mapping = (search, replacement) ->
    ->
      mappingExpand = (input) ->
        return unless input?
        return input unless replacement?
        return input.replace new RegExp(search, 'g'), ->
          args = arguments
          expand(replacement).replace /\\(\d+)/g, (m, n) -> args[n]

  repeat = (value, range) ->
    repeatExpand = ->
      max = range.min + choose (range.max - range.min + 1)
      (expand value for [1 .. max] by 1).join ''

  transform = (input, through) ->
    transformExpand = ->
      inputExpanded = expand input
      throughExpanded = expand through
      unless typeof throughExpanded is 'function'
        # console.warn "Transform expression '#{fnExpanded?.toString()}' is not a function"
        return inputExpanded
      throughExpanded inputExpanded


  return # DO NOT remove this line
