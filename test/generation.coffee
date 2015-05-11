_ = require 'lodash'
rmutt = require '..'
{expect} = require 'chai'

describe 'generation', ->

  expectUsingIteration = (grammar, done, expected, options) ->
    options ?= {}
    rmutt.compile grammar, options, (err, result) ->
      return done err if err?
      results = []
      count = 0
      expected.forEach (value, index) ->
        iterationOptions = _.clone options
        iterationOptions.iteration = index
        result.compiled iterationOptions, (err, result) ->
          return done err if err?
          results[index] = result.generated
          count++
          if count is expected.length
            expect(results).to.deep.equal expected
            done()

  it 'more than one dash in rule identifier', (done) ->
    grammar = 'a-b-c:"x";'
    expectUsingIteration grammar, done, [
      'x'
    ]

  it 'choice selection', (done) ->
    grammar = """
      t: "0"|"1"|"2";
    """
    expectUsingIteration grammar, done, [
      '0'
      '1'
      '2'
    ]

  it 'generates random seed (number by default)', (done) ->
    grammar = """
      t: $options.randomSeed;
    """
    rmutt.generate grammar, (err, result) ->
      return done err if err?
      expect(result.options.randomSeedType).to.equal 'integer'
      expect(result.options.randomSeed).to.be.a 'number'
      expect(result.options.randomSeed).to.equal +(result.generated)
      done()

  it 'uses random seed', (done) ->
    grammar = """
      t: "0"|"1"|"2";
    """
    rmutt.generate grammar, randomSeed: 12345, (err, result) ->
      return done err if err?
      expect(result.options.randomSeed).to.equal 12345
      done()

  it 'generates array random seed', (done) ->
    grammar = """
      t: "0"|"1"|"2";
    """
    rmutt.generate grammar, randomSeedType: 'array', (err, result) ->
      return done err if err?
      expect(result.options.randomSeedType).to.equal 'array'
      expect(result.options.randomSeed).to.be.instanceof Array
      expect(result.options.randomSeed).to.have.length 16
      done()

  it 'empty choice', (done) ->
    grammar = """
      soldOut: | |  |    "<b>SOLD OUT</b>" | |  |;
    """
    expectUsingIteration grammar, done, [
      ''
      ''
      ''
      '<b>SOLD OUT</b>'
      ''
    ]

  it 't2 - recursion', (done) ->
    grammar = """
      t: "0"|a;
      a: "1"|t;
    """
    expectUsingIteration grammar, done, [
      '0'
      '1'
      '0'
          '0'
      '0'
      '1'
      '0'
          '1'
      '0'
      '1'
      '0'
          '0'
      '0'
      '1'
      '0'
              '0'
    ]

  it 't2b - circular recursion', (done) ->
    grammar = """
      foo: "yes" bar;
      bar: foo;
    """
    rmutt.generate grammar, (err, result) ->
      expect(err?.message).to.match /Maximum call stack size exceeded/
      done()

  it 't2c - configurable maximum stack depth', (done) ->
    grammar = """
      foo: "yes" bar;
      bar: foo;
    """
    expectUsingIteration grammar, done, [
      'yesyesyesyesyesyesyesyesyesyes'
    ], maxStackDepth: 20

  it 't3 - anonymous rules', (done) ->
    grammar = """
      t: "a" ("b"|"c") "d";
    """
    expectUsingIteration grammar, done, [
      'abd'
      'acd'
    ]

  it 't4 - nested anonymous rules', (done) ->
    grammar = """
      t: "a" ("b"|("c"|"d"));
    """
    expectUsingIteration grammar, done, [
      'ab'
      'ac'
      'ab'
      'ad'
    ]

  it 't5 - repetition', (done) ->
    grammar = """
      t: "a"{2} "b"{2,3} "c"? "d"* "e"+;
    """
    expectUsingIteration grammar, done, [
      'aabbe'
      'aabbbe'
      'aabbce'
      'aabbbce'
      'aabbde'
      'aabbbde'
      'aabbcde'
      'aabbbcde'
      'aabbdde'
      'aabbbdde'
      'aabbcdde'
      'aabbbcdde'
      'aabbddde'
      'aabbbddde'
      'aabbcddde'
      'aabbbcddde'
      'aabbdddde'
      'aabbbdddde'
      'aabbcdddde'
      'aabbbcdddde'
      'aabbddddde'
      'aabbbddddde'
      'aabbcddddde'
      'aabbbcddddde'
    ]

  it 'repeat with variety', (done) ->
    grammar = """
      top: id[a]{2};
      a: "x", "y";
      id[w]: w;
    """
    expectUsingIteration grammar, done, [
      'xx'
      'yx'
      'xy'
      'yy'
    ]

  it 'repetition in package', (done) ->
    grammar = """
      package p;
      top: r{1};
      r: "R";
    """
    expectUsingIteration grammar, done, [
      'R'
    ]

  it 't6 - embedded definitions', (done) ->
    grammar = """
      t: (a: "0" | "1") a;
    """
    expectUsingIteration grammar, done, [
      '0'
      '1'
    ]

  it 'embedded definitions', (done) ->
    grammar = """
      meta-vp:
      (iv: "ate") (prep: "with") vp,
      (iv: "yelled") (prep: "at") vp,
      (iv: "waited") (prep: "for","on","with") vp;
      vp: iv " " adv " " pp;
      pp: prep " " obj;
      obj: "you", "me";
      adv: "patiently", "impatiently";
    """
    rmutt.compile grammar, (err, result) ->
      return done err if err?

      count = 0
      expected = 3

      result.compiled iteration: 0, (err, result) ->
        return done err if err?
        expect(result.generated).to.equal 'ate patiently with you'
        done() if ++count is expected

      result.compiled iteration: 200, (err, result) ->
        return done err if err?
        expect(result.generated).to.equal 'waited patiently for me'
        done() if ++count is expected

      result.compiled iteration: 400, (err, result) ->
        return done err if err?
        expect(result.generated).to.equal 'yelled impatiently at you'
        done() if ++count is expected

  it 't7 - variables', (done) ->
    grammar = """
      t: (a = "0" | "1") a a;
    """
    expectUsingIteration grammar, done, [
      '00'
      '11'
    ]

  it 'variable', (done) ->
    grammar = """
      s: (character = name, position) character " said, 'I am " character ", so nice to meet you.'";
      name: title " " firstName " " lastName;
      title: "Dr.", "Mr.", "Mrs.", "Ms";
      firstName: "Nancy", "Reginald", "Edna", "Archibald";
      lastName: "McPhee", "Eaton-Hogg", "Worthingham";
      position: "the butler", "the chauffeur";
    """
    expectUsingIteration grammar, done, [
      "Dr. Nancy McPhee said, 'I am Dr. Nancy McPhee, so nice to meet you.'"
      "the butler said, 'I am the butler, so nice to meet you.'"
    ]

  it 'indirection', (done) ->
    grammar = """
      start:  sentence-about[animal];
      animal: "dog", "cat";
      sentence-about[subject]: @subject " is a " subject;
      dog: "Fido", "Spot";
      cat: "Tiddles", "Fluffy";
    """
    expectUsingIteration grammar, done, [
      'Fido is a dog'
      'Tiddles is a cat'
      'Spot is a dog'
      'Fluffy is a cat'
    ]

  it 't8 - mappings', (done) ->
    grammar = """
      a: b > ("0" % "a" "1" % "b");
      b: "0" | "1";
    """
    expectUsingIteration grammar, done, [
      'a'
      'b'
    ]

  it 't8a - mappings', (done) ->
    grammar = """
      a: "i like to eat apples and bananas" > "i" % "u";
    """
    expectUsingIteration grammar, done, [
      'u luke to eat apples and bananas'
    ]

  it 't8b - mappings', (done) ->
    grammar = """
      a: "i like to eat apples and bananas" > ("i" % u);
      u: "u";
    """
    expectUsingIteration grammar, done, [
      'u luke to eat apples and bananas'
    ]

  it 'mapping in package', (done) ->
    grammar = """
      package test;
      top: "xxx" > "x" % a;
      a: "y";
    """
    expectUsingIteration grammar, done, [
      'yyy'
    ]

  it 't13 - complex mapping syntax', (done) ->
    grammar = """
      a: ("a"|"b")>("a"%("0"|"zero") "b"%("1"|"one"));
    """
    expectUsingIteration grammar, done, [
      '0'
      '1'
      'zero'
      'one'
    ]

  it 't9 - regexes', (done) ->
    grammar = """
      a: "i like to eat apples and bananas" > /[aeiou]+/oo/;
    """
    expectUsingIteration grammar, done, [
      'oo lookoo too oot oopploos oond boonoonoos'
    ]

  it 't9b - regexes', (done) ->
    grammar = """
      a: "i like to eat apples and bananas" > (/[aeiou]+/oo/ /loo/x/);
    """
    expectUsingIteration grammar, done, [
      'oo xkoo too oot ooppxs oond boonoonoos'
    ]

  it 't9c - backreferences', (done) ->
    grammar = """
      a: "a bad apple" > /a (.+) (.+)/i want the \\2s \\1ly/;
    """
    expectUsingIteration grammar, done, [
      'i want the apples badly'
    ]

  it 't9 - regexes with /', (done) ->
    grammar = """
      a: "a // //// b" > /[\\/]+/-/;
    """
    expectUsingIteration grammar, done, [
      'a - - b'
    ]

  it 't10 - transformation chaining', (done) ->
    grammar = """
      thing: name > deleteVowels > slangify > deleteVowels;
      deleteVowels: /[aeiou]//;
      slangify: "chck" % "chiggidy" "snp" % "snippidy";
      name: "check" | "chuck" | "snap" | "snipe";
    """
    expectUsingIteration grammar, done, [
      'chggdy'
      'chggdy'
      'snppdy'
      'snppdy'
    ]

  it 'transformation 1', (done) ->
    grammar = """
      a: "abc" > ("b" % "x");
    """
    expectUsingIteration grammar, done, [
      'axc'
    ]

  it 'transformation 2', (done) ->
    grammar = """
      a: "abc" > b;
      b: "b" % "x";
    """
    expectUsingIteration grammar, done, [
      'axc'
    ]

  it 'transformation 3', (done) ->
    grammar = """
      a: "abc" > b;
      b: "b" % "x" "c" % "y";
    """
    expectUsingIteration grammar, done, [
      'axy'
    ]

  it 'packages', (done) ->
    grammar = """
      package p1;

      a: b p2.a;
      b: "p1b";

      package p2;

      a: " p2a " b;
      b: "p2b";
    """
    expectUsingIteration grammar, done, [
      'p1b p2a p2b'
    ]

  it 't11 - packages', (done) ->
    grammar = """
      package lesson;

      sentence: o " starts with the letter 'O', " greeting.o;
      o: "oatmeal" | "ogre";

      package greeting;

      s: "hello there " o;
      o: "beautiful" | "Mr. Smarty Pants";
    """
    expectUsingIteration grammar, done, [
      "oatmeal starts with the letter 'O', beautiful"
      "ogre starts with the letter 'O', beautiful"
      "oatmeal starts with the letter 'O', Mr. Smarty Pants"
      "ogre starts with the letter 'O', Mr. Smarty Pants"
    ]

  describe 'multiplier', ->

    it 't12 - probability multipliers', (done) ->
      grammar = """
        package test;
        a: "0" 3| "1";
      """
      expectUsingIteration grammar, done, [
        '0'
        '0'
        '0'
        '1'
      ]

    it 't12b - ignore multiplier outside choice', (done) ->
      grammar = """
        package test;
        a: "x" "y" "z" 3;
      """
      expectUsingIteration grammar, done, [
        'xyz'
      ]

  it 't14 - includes', (done) ->
    grammar = """
      #include "test/t14b.rm"
      a: b;
    """
    expectUsingIteration grammar, done, [
      'yes!'
    ]

  describe 'rule arguments', ->

    it 't16 - positional arguments', (done) ->
      grammar = """
        foo: (bar["thing","blah","foo"] "ie"){20};
        bar[a,b,c]: "i like " _1 " and " b " and " _3;
      """
      expectUsingIteration grammar, done, [
        'i like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooie'
      ]

    it 'terms as argument', (done) ->
      grammar = """
        top: a[b c];
        a[x]: x;
      """
      expectUsingIteration grammar, done, [
        'bc'
      ]

    it 'rule invocation as argument', (done) ->
      grammar = """
        package test;
        top: a[b["c"]];
        a[p]:p;
        b[p]:p;
      """
      expectUsingIteration grammar, done, [
        'c'
      ]

    it 'argument has local precedence in package', (done) ->
      grammar = """
        package test;
        top: a['x'];
        a[p]: p;
        p: 'y';
      """
      expectUsingIteration grammar, done, [
        'x'
      ]

  describe 'scope', ->

    it 't15 - scope qualifiers', (done) ->
      grammar = """
        r: ((a="foo") a ($b="bar")) b " "
        ((c:"foo"|"bar") c ($d:"baz"|"quux") d) d "\\n";
      """
      expectUsingIteration grammar, done, [
        'foobar foobazbaz\n'
        'foobar barbazbaz\n'
        'foobar fooquuxbaz\n'
        'foobar barquuxbaz\n'
        'foobar foobazquux\n'
        'foobar barbazquux\n'
        'foobar fooquuxquux\n'
        'foobar barquuxquux\n'
      ]

    # more examples of parent: math.rm, sva.rm
    # more examples of root: turing.rm, SecomPR.rm
    it 't17 - scope qualifiers: parent', (done) ->
      grammar = """
        tests:
         local.top " "
         root.top " "
         parent.top " "
        ;

        package local;

        top: A X;

        A: (X="1") B X;
        B: (X="2") C X;
        C: (X="3") X;

        package parent;

        top: A X;

        A: (X="1") B X;
        B: (X="2") C X;
        C: (^X="3") X;

        package root;

        top: A X;

        A: (X="1") B X;
        B: (X="2") C X;
        C: ($X="3") X;
      """
      expectUsingIteration grammar, done, [
        '321local.X 2213 331parent.X '
      ]

  it 't18 - imports', (done) ->
    grammar = """
      top: baz.quux;

      package foo;

      bar: "quux"|"fnord";

      package baz;

      import bar from foo;

      quux: "snooby " bar;

    """
    expectUsingIteration grammar, done, [
      'snooby quux'
      'snooby fnord'
    ]

  it 'multiple import', (done) ->
    grammar = """
      package util;
      xuc: /a/ % "A";
      uc[text]: text > xuc;
      xtc: /^a/ % "A";
      tc[text]: text > xtc;

      package test;
      import uc, tc from util;
      top: tc["aaa"] " " uc["aaa"];
    """
    expectUsingIteration grammar, done, [
      'Aaa AAA'
    ], entry: 'test.top'

  describe 'entry rule', ->

    beforeEach ->
      @grammar = """
        a:"A";
        b:"B";
        c:"C";
      """

    it 'first rule by default', (done) ->
      rmutt.generate @grammar, (err, result) ->
        return done err if err?
        expect(result.generated).to.equal 'A'
        done()

    it 'defined in transpilation', (done) ->
      rmutt.compile @grammar, entry: 'b', (err, result) ->
        return done err if err?
        result.compiled (err, result) ->
          return done err if err?
          expect(result.generated).to.equal 'B'
          done()

    it 'override defined in transpilation', (done) ->
      rmutt.compile @grammar, entry: 'b', (err, result) ->
        return done err if err?
        result.compiled entry: 'c', (err, result) ->
          return done err if err?
          expect(result.generated).to.equal 'C'
          done()

  describe 'code block', ->

    it 'evaluates rule arguments as local variables', (done) ->
      grammar = """
        top: fn["1","2","3"];
        fn[a, b, c]: {
          return c + b + a;
        };
      """
      expectUsingIteration grammar, done, [
        '321'
      ]

    it 'evaluates anonymous expression', (done) ->
      grammar = """
        top: "1+2=" ({ return 1+2 });
      """
      expectUsingIteration grammar, done, [
        '1+2=3'
      ]

    it 'evaluates undefined as empty string', (done) ->
      grammar = """
        top: { return };
      """
      expectUsingIteration grammar, done, [
        ''
      ]

    it 'evaluates null as empty string', (done) ->
      grammar = """
        top: { return null };
      """
      expectUsingIteration grammar, done, [
        ''
      ]

    it 'evaluates expression in package', (done) ->
      grammar = """
        package test;
        top: fn["1", "2", "3"];
        fn[a, b, c]: {
          return c + b + a;
        };
      """
      expectUsingIteration grammar, done, [
        '321'
      ]

    it 'evaluates expression with curly brackets', (done) ->
      grammar = """
        top: fn["x" | "y" | "z"];
        fn[k]: {
          var map = {
            x: 1,
            y: 2,
            z: 3
          };
          return map[k];
        };
      """
      expectUsingIteration grammar, done, [
        '1'
        '2'
        '3'
      ]

    it 'evaluates named rule as transformation', (done) ->
      grammar = """
        top: "abcd" > (asciify["b"] "c"%"x" asciify["d"]);
        asciify[char]: {
          return function (input) {
            return input.replace(char, char.charCodeAt(0));
          };
        };
      """
      expectUsingIteration grammar, done, [
        'a98x100'
      ]

    it 'evaluates anonymous rule as transformation', (done) ->
      grammar = """
        top: "abcd" > (
          "c"%"x"
          ({
            return function (input) {
              return input.toUpperCase();
            };
          })
        );
      """
      expectUsingIteration grammar, done, [
        'ABXD'
      ]

  describe 'external rules', ->

    it 'handles missing transformation', (done) ->
      grammar = """
        top: expr " = " (expr > calc);
        expr: "1 + 2";
      """
      expectUsingIteration grammar, done, [
        '1 + 2 = 1 + 2'
      ]
      # .to.throw /'calc' is not a function/

    it 'used as transformation', (done) ->
      grammar = """
        top: expr " = " (expr > calc);
        expr: "1 + 2";
      """
      options =
        externals:
          calc: (input) ->
            (eval input).toString()

      expectUsingIteration grammar, done, [
        '1 + 2 = 3'
      ], options

    it 'handles missing parameterized rule', (done) ->
      grammar = """
        top: expr " = " calc[expr];
        expr: "1 + 2";
      """
      rmutt.generate grammar, (err, result) ->
        expect(err?.message).to.match /Missing parameterized rule/
        done()

    it 'used as parameterized rule', (done) ->
      grammar = """
        top: expr " = " calc[expr, "USD"];
        expr: "1 + 2";
      """
      options =
        externals:
          calc: (input, unit) ->
            unit + ' ' + (eval input).toString()

      expectUsingIteration grammar, done, [
        '1 + 2 = USD 3'
      ], options

    it 'used as variable', (done) ->
      grammar = """
        top: name;
      """
      options =
        externals:
          name: 'value'

      expectUsingIteration grammar, done, [
        'value'
      ], options

    it 'used as composed transformation', (done) ->
      grammar = """
        top: "abcd" > (asciify["b"] "c"%"x" asciify["d"]);
      """
      options =
        externals:
          asciify: (char) ->
            (input) ->
              input.replace(char, char.charCodeAt(0))

      expectUsingIteration grammar, done, [
        'a98x100'
      ], options

    # TODO: #include externals.js
