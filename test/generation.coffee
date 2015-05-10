rmutt = require '..'
expect = require('chai').expect

describe 'generation', ->

  expectUsingIteration = (grammar, expected) ->
    generator = rmutt.compile grammar
    for result, index in expected
      expect(generator iteration: index)
        .to.equal result

  it 'more than one dash in rule identifier', ->
    grammar = 'a-b-c:"x";'
    expect(rmutt.generate grammar)
      .to.equal 'x'

  it 't1 - random selection', ->
    grammar = """
      t: "0"|"1"|"2";
    """
    expectUsingIteration grammar, [
      '0'
      '1'
      '2'
    ]

  it 'empty choice', ->
    grammar = """
      soldOut: | |  |    "<b>SOLD OUT</b>" | |  |;
    """
    expectUsingIteration grammar, [
      ''
      ''
      ''
      '<b>SOLD OUT</b>'
      ''
    ]

  it 't2 - recursion', ->
    grammar = """
      t: "0"|a;
      a: "1"|t;
    """
    expectUsingIteration grammar, [
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

  it 't2b - circular recursion', ->
    grammar = """
      foo: "yes" bar;
      bar: foo;
    """
    expect(-> rmutt.generate grammar)
      .to.throw /Maximum call stack size exceeded/

  it 't2c - configurable maximum stack depth', ->
    grammar = """
      foo: "yes" bar;
      bar: foo;
    """
    expect(rmutt.generate grammar, maxStackDepth: 20)
      .to.equal 'yesyesyesyesyesyesyesyesyesyes'

  it 't3 - anonymous rules', ->
    grammar = """
      t: "a" ("b"|"c") "d";
    """
    expectUsingIteration grammar, [
      'abd'
      'acd'
    ]

  it 't4 - nested anonymous rules', ->
    grammar = """
      t: "a" ("b"|("c"|"d"));
    """
    expectUsingIteration grammar, [
      'ab'
      'ac'
      'ab'
      'ad'
    ]

  it 't5 - repetition', ->
    grammar = """
      t: "a"{2} "b"{2,3} "c"? "d"* "e"+;
    """
    expectUsingIteration grammar, [
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

  it 'repeat with variety', ->
    grammar = """
      top: id[a]{2};
      a: "x", "y";
      id[w]: w;
    """
    expectUsingIteration grammar, [
      'xx'
      'yx'
      'xy'
      'yy'
    ]

  it 'repetition in package', ->
    grammar = """
      package p;
      top: r{1};
      r: "R";
    """
    expect(rmutt.generate grammar)
      .to.equal 'R'

  it 't6 - embedded definitions', ->
    grammar = """
      t: (a: "0" | "1") a;
    """
    expectUsingIteration grammar, [
      '0'
      '1'
    ]

  it 'embedded definitions', ->
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
    generator = rmutt.compile grammar

    expect(generator iteration: 0)
      .to.equal 'ate patiently with you'

    expect(generator iteration: 200)
      .to.equal 'waited patiently for me'

    expect(generator iteration: 400)
      .to.equal 'yelled impatiently at you'

  it 't7 - variables', ->
    grammar = """
      t: (a = "0" | "1") a a;
    """
    expectUsingIteration grammar, [
      '00'
      '11'
    ]

  it 'variable', ->
    grammar = """
      s: (character = name, position) character " said, 'I am " character ", so nice to meet you.'";
      name: title " " firstName " " lastName;
      title: "Dr.", "Mr.", "Mrs.", "Ms";
      firstName: "Nancy", "Reginald", "Edna", "Archibald";
      lastName: "McPhee", "Eaton-Hogg", "Worthingham";
      position: "the butler", "the chauffeur";
    """
    expectUsingIteration grammar, [
      "Dr. Nancy McPhee said, 'I am Dr. Nancy McPhee, so nice to meet you.'"
      "the butler said, 'I am the butler, so nice to meet you.'"
    ]

  it 'indirection', ->
    grammar = """
      start:  sentence-about[animal];
      animal: "dog", "cat";
      sentence-about[subject]: @subject " is a " subject;
      dog: "Fido", "Spot";
      cat: "Tiddles", "Fluffy";
    """
    expectUsingIteration grammar, [
      'Fido is a dog'
      'Tiddles is a cat'
      'Spot is a dog'
      'Fluffy is a cat'
    ]

  it 't8 - mappings', ->
    grammar = """
      a: b > ("0" % "a" "1" % "b");
      b: "0" | "1";
    """
    expectUsingIteration grammar, [
      'a'
      'b'
    ]

  it 't8a - mappings', ->
    grammar = """
      a: "i like to eat apples and bananas" > "i" % "u";
    """
    expectUsingIteration grammar, [
      'u luke to eat apples and bananas'
    ]

  it 't8b - mappings', ->
    grammar = """
      a: "i like to eat apples and bananas" > ("i" % u);
      u: "u";
    """
    expectUsingIteration grammar, [
      'u luke to eat apples and bananas'
    ]

  it 'mapping in package', ->
    grammar = """
      package test;
      top: "xxx" > "x" % a;
      a: "y";
    """
    expect(rmutt.generate grammar)
      .to.equal 'yyy'

  it 't13 - complex mapping syntax', ->
    grammar = """
      a: ("a"|"b")>("a"%("0"|"zero") "b"%("1"|"one"));
    """
    expectUsingIteration grammar, [
      '0'
      '1'
      'zero'
      'one'
    ]

  it 't9 - regexes', ->
    grammar = """
      a: "i like to eat apples and bananas" > /[aeiou]+/oo/;
    """
    expectUsingIteration grammar, [
      'oo lookoo too oot oopploos oond boonoonoos'
    ]

  it 't9b - regexes', ->
    grammar = """
      a: "i like to eat apples and bananas" > (/[aeiou]+/oo/ /loo/x/);
    """
    expectUsingIteration grammar, [
      'oo xkoo too oot ooppxs oond boonoonoos'
    ]

  it 't9c - backreferences', ->
    grammar = """
      a: "a bad apple" > /a (.+) (.+)/i want the \\2s \\1ly/;
    """
    expectUsingIteration grammar, [
      'i want the apples badly'
    ]

  it 't9 - regexes with /', ->
    grammar = """
      a: "a // //// b" > /[\\/]+/-/;
    """
    expect(rmutt.generate grammar)
      .to.equal 'a - - b'

  it 't10 - transformation chaining', ->
    grammar = """
      thing: name > deleteVowels > slangify > deleteVowels;
      deleteVowels: /[aeiou]//;
      slangify: "chck" % "chiggidy" "snp" % "snippidy";
      name: "check" | "chuck" | "snap" | "snipe";
    """
    expectUsingIteration grammar, [
      'chggdy'
      'chggdy'
      'snppdy'
      'snppdy'
    ]

  it 'transformation 1', ->
    grammar = """
      a: "abc" > ("b" % "x");
    """
    expect(rmutt.generate grammar)
      .to.equal 'axc'

  it 'transformation 2', ->
    grammar = """
      a: "abc" > b;
      b: "b" % "x";
    """
    expect(rmutt.generate grammar)
      .to.equal 'axc'

  it 'transformation 3', ->
    grammar = """
      a: "abc" > b;
      b: "b" % "x" "c" % "y";
    """
    expect(rmutt.generate grammar)
      .to.equal 'axy'

  it 'packages', ->
    grammar = """
      package p1;

      a: b p2.a;
      b: "p1b";

      package p2;

      a: " p2a " b;
      b: "p2b";
    """
    expect(rmutt.generate grammar)
      .to.equal "p1b p2a p2b"

  it 't11 - packages', ->
    grammar = """
      package lesson;

      sentence: o " starts with the letter 'O', " greeting.o;
      o: "oatmeal" | "ogre";

      package greeting;

      s: "hello there " o;
      o: "beautiful" | "Mr. Smarty Pants";
    """
    expectUsingIteration grammar, [
      "oatmeal starts with the letter 'O', beautiful"
      "ogre starts with the letter 'O', beautiful"
      "oatmeal starts with the letter 'O', Mr. Smarty Pants"
      "ogre starts with the letter 'O', Mr. Smarty Pants"
    ]

  describe 'multiplier', ->

    it 't12 - probability multipliers', ->
      grammar = """
        package test;
        a: "0" 3| "1";
      """
      expectUsingIteration grammar, [
        '0'
        '0'
        '0'
        '1'
      ]

    it 't12b - ignore multiplier outside choice', ->
      grammar = """
        package test;
        a: "x" "y" "z" 3;
      """
      expect(rmutt.generate grammar)
        .to.equal 'xyz'

  it 't14 - includes', ->
    grammar = """
      #include "test/t14b.rm"
      a: b;
    """
    expect(rmutt.generate grammar, iteration: 0)
      .to.equal 'yes!'

  describe 'rule arguments', ->

    it 't16 - positional arguments', ->
      grammar = """
        foo: (bar["thing","blah","foo"] "ie"){20};
        bar[a,b,c]: "i like " _1 " and " b " and " _3;
      """
      expect(rmutt.generate grammar)
        .to.equal 'i like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooie'

    it 'terms as argument', ->
      grammar = """
        top: a[b c];
        a[x]: x;
      """
      expect(rmutt.generate grammar)
        .to.equal 'bc'

    it 'rule invocation as argument', ->
      grammar = """
        package test;
        top: a[b["c"]];
        a[p]:p;
        b[p]:p;
      """
      expect(rmutt.generate grammar)
        .to.equal 'c'

    it 'argument has local precedence in package', ->
      grammar = """
        package test;
        top: a['x'];
        a[p]: p;
        p: 'y';
      """
      expect(rmutt.generate grammar)
        .to.equal 'x'

  describe 'scope', ->

    it 't15 - scope qualifiers', ->
      grammar = """
        r: ((a="foo") a ($b="bar")) b " "
        ((c:"foo"|"bar") c ($d:"baz"|"quux") d) d "\\n";
      """
      expectUsingIteration grammar, [
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
    it 't17 - scope qualifiers: parent', ->
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

      expect(rmutt.generate grammar)
        .to.equal '321local.X 2213 331parent.X '

  it 't18 - imports', ->
    grammar = """
      top: baz.quux;

      package foo;

      bar: "quux"|"fnord";

      package baz;

      import bar from foo;

      quux: "snooby " bar;

    """
    expectUsingIteration grammar, [
      'snooby quux'
      'snooby fnord'
    ]

  it 'multiple import', ->
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
    expect(rmutt.generate grammar, entry: 'test.top')
      .to.equal 'Aaa AAA'

  describe 'entry rule', ->

    beforeEach ->
      @grammar = """
        a:"A";
        b:"B";
        c:"C";
      """

    it 'first rule by default', ->
      expect(rmutt.generate @grammar)
        .to.equal 'A';

    it 'defined in transpilation', ->
      generator = rmutt.compile @grammar, entry: 'b'
      expect(generator())
        .to.equal 'B';

    it 'override defined in transpilation', ->
      generator = rmutt.compile @grammar, entry: 'b'
      expect(generator(entry: 'c'))
        .to.equal 'C';

  describe 'external rules', ->

    it 'handles missing transformation', ->
      grammar = """
        top: expr " = " (expr > calc);
        expr: "1 + 2";
      """
      expect(rmutt.generate grammar)
        .to.equal '1 + 2 = 1 + 2'
        # .to.throw /'calc' is not a function/

    it 'used as transformation', ->
      grammar = """
        top: expr " = " (expr > calc);
        expr: "1 + 2";
      """
      options =
        externals:
          calc: (input) ->
            (eval input).toString()

      expect(rmutt.generate grammar, options)
        .to.equal '1 + 2 = 3'

    it 'handles missing parameterized rule', ->
      grammar = """
        top: expr " = " calc[expr];
        expr: "1 + 2";
      """
      expect(-> rmutt.generate grammar)
        .to.throw /Missing parameterized rule/

    it 'used as parameterized rule', ->
      grammar = """
        top: expr " = " calc[expr, "USD"];
        expr: "1 + 2";
      """
      options =
        externals:
          calc: (input, unit) ->
            unit + ' ' + (eval input).toString()

      expect(rmutt.generate grammar, options)
        .to.equal '1 + 2 = USD 3'

    it 'used as variable', ->
      grammar = """
        top: name;
      """
      options =
        externals:
          name: 'value'

      expect(rmutt.generate grammar, options)
        .to.equal 'value'

    it 'used as composed transformation', ->
      grammar = """
        top: "abcd" > (asciify["b"] "c"%"x" asciify["d"]);
      """
      options =
        externals:
          asciify: (char) ->
            (input) ->
              input.replace(char, char.charCodeAt(0))

      expect(rmutt.generate grammar, options)
        .to.equal 'a98x100'

    # TODO: #include externals.js
