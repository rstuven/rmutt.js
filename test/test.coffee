rmutt = require '..'
expect = require('chai').expect

expectWithOracle = (source, expected) ->
  compiled = rmutt.compile source
  for result, index in expected.reverse()
    expect(compiled oracle: index)
      .to.equal result

# TODO: empty grammar test
# TODO: undefined config test

describe 'rmutt', ->

  examplesDir = __dirname + '/../examples/'

  describe 'examples', ->

    example = (file) ->
      fs = require 'fs'
      source = fs.readFileSync examplesDir + file, 'utf8'
      # console.log source

      # console.log('\n' + file + ':')
      # console.time('compile')
      compiled = rmutt.compile source,
        workingDir: examplesDir
        header: file
        cache: false
        cacheRegenerate: true
      # console.timeEnd('compile')
      # console.log compiled.toString()

      # console.time('generate')
      output = compiled()
      # console.timeEnd('generate')

      # console.log()
      # console.log output

    # TODO: skipped errors
    it 'addresses.rm', -> example 'addresses.rm'
    it 'author.rm', -> example 'author.rm'
    it 'bands.rm', -> example 'bands.rm'
    it 'chars.rm', -> example 'chars.rm'
    it 'dialogue.rm', -> example 'dialogue.rm'
    it 'directions.rm', -> example 'directions.rm'
    it 'dissertation.rm', -> example 'dissertation.rm'
    it 'dotree.rm', -> example 'dotree.rm'
    it 'eng.rm', -> example 'eng.rm'
    it 'gramma.rm', -> example 'gramma.rm'
    it 'grammar.rm', -> example 'grammar.rm'
    it.skip 'jcr_sv.rm', -> example 'jcr_sv.rm' # error
    it.skip 'math.rm', -> example 'math.rm' # error
    it 'neruda.rm', -> example 'neruda.rm'
    it 'numbers.rm', -> example 'numbers.rm'
    it 'password.rm', ->  example 'password.rm'
    it 'password2.rm', -> example 'password2.rm'
    it 'recipe.rm', -> example 'recipe.rm'
    it 'sentence.rm', -> example 'sentence.rm'
    it 'slogan.rm', -> example 'slogan.rm'
    it 'spew.rm', -> example 'spew.rm'
    it 'spew_xml.rm', -> example 'spew_xml.rm'
    it 'story.rm', -> example 'story.rm'
    it.skip 'sva.rm', -> example 'sva.rm' # error
    it 'tree.rm', -> example 'tree.rm'
    it.skip 'turing.rm', -> example 'turing.rm' # error
    it 'url.rm', -> example 'url.rm'
    it 'wine.rm', -> example 'wine.rm'
    it 'xml.rm', -> example 'xml.rm'

  it 'rule call from parameter', ->
    source = """
      package test;
      top: a[b["c"]];
      a[p]:p;
      b[p]:p;
    """
    expect(rmutt.generate source)
      .to.equal 'c'

  it 'more than one dash in rule identifier', ->
    source = 'a-b-c:"x";'
    expect(rmutt.generate source)
      .to.equal 'x'

  it 'repeat with variety', ->
    source = """
      top: a{2};
      a: "x", "y";
    """
    expectWithOracle source, [
      'yy'
      'xy'
      'yx'
      'xx'
    ]

  it 'terms parameter', ->
    source = """
      top: a[b c];
      a[x]: x;
    """
    expect(rmutt.generate source)
      .to.equal 'bc'

  it 'paramater has local precedence in package', ->
    source = """
      package test;
      top: a['x'];
      a[p]: p;
      p: 'y';
    """
    expect(rmutt.generate source)
      .to.equal 'x'

describe 'rmutt', ->

  it 'should be fast to parse nested parens', ->
    @timeout 100
    source = "a:(((((((b)))))));"
    rmutt.compile source

  it 'should be fast to parse this rule (from math.rm)', ->
    @timeout 500
    source = """
      add[a,b]:
        zupfx[
         (sum="NaN")
         (ignore=a>"0"%(^sum=b))
         (ignore=b>"0"%(^sum=a))
         (sum>"NaN"%(
           (l = add_d[lsd[a],lsd[b]])
           (m=add[zpfx[msds[a]],zpfx[msds[b]]])
           (ignore=(msds[l] > "1" % ((^m=inc[m]) (^l=l > /1(.)/\\1/))))
           m l))
        ];
    """
    rmutt.compile source

  it '_t0', ->
    source = """
      meta-vp:
      (iv: "ate") (prep: "with") vp,
      (iv: "yelled") (prep: "at") vp,
      (iv: "waited") (prep: "for","on","with") vp;
      vp: iv " " adv " " pp;
      pp: prep " " obj;
      obj: "you", "me";
      adv: "patiently", "impatiently";
    """
    compiled = rmutt.compile source

    expect(compiled oracle: 0)
      .to.equal 'ate patiently with you'

    expect(compiled oracle: 200)
      .to.equal 'waited patiently for me'

    expect(compiled oracle: 400)
      .to.equal 'yelled impatiently at you'

  it 't0', ->
    source = """
      s: (character = name, position) character " said, 'I am " character ", so nice to meet you.'";
      name: title " " firstName " " lastName;
      title: "Dr.", "Mr.", "Mrs.", "Ms";
      firstName: "Nancy", "Reginald", "Edna", "Archibald";
      lastName: "McPhee", "Eaton-Hogg", "Worthingham";
      position: "the butler", "the chauffeur";
    """
    expectWithOracle source, [
      "the butler said, 'I am the butler, so nice to meet you.'"
      "Dr. Nancy McPhee said, 'I am Dr. Nancy McPhee, so nice to meet you.'"
    ]

  it 't1 - random selection', ->
    source = """
      t: "0"|"1"|"2";
    """
    expectWithOracle source, [
      '2'
      '1'
      '0'
    ]

  it 'empty choice', ->
    source = """
      soldOut: | |  |    "<b>SOLD OUT</b>" | |  |;
    """
    expectWithOracle source, [
      ''
      '<b>SOLD OUT</b>'
      ''
      ''
      ''
    ]

  it 't2 - recursion', ->
    source = """
      t: "0"|a;
      a: "1"|t;
    """
    expectWithOracle source, [
      '1'
      '0', '1', '0', '0', '0', '1', '0'
    ]

  it 't2b - circular recursion', ->
    source = """
      t: "0" a;
      a: "1" t;
    """
    expect(-> rmutt.generate source)
      .to.throw /Maximum call stack size exceeded/

  it 't2b - circular recursion configurable', ->
    source = """
      t: "0" a;
      a: "1" t;
    """
    expect(rmutt.generate source, maxStackDepth: 10)
      .to.equal '01010101010'

  it 't3 - anonymous rules', ->
    source = """
      t: "a" ("b"|"c") "d";
    """
    expectWithOracle source, [
      'acd'
      'abd'
    ]

  it 't4 - nested anonymous rules', ->
    source = """
      t: "a" ("b"|("c"|"d"));
    """
    expectWithOracle source, [
      'ad'
      'ab'
      'ac'
      'ab'
    ]

  it 't5 - repetition', ->
    source = """
      t: "a"{2} "b"{2,3} "c"? "d"* "e"+;
    """
    expectWithOracle source, [
      'aabbbcddddde'
      'aabbcddddde'
      'aabbbddddde'
      'aabbddddde'
      'aabbbcdddde'
      'aabbcdddde'
      'aabbbdddde'
      'aabbdddde'
      'aabbbcddde'
      'aabbcddde'
      'aabbbddde'
      'aabbddde'
      'aabbbcdde'
      'aabbcdde'
      'aabbbdde'
      'aabbdde'
      'aabbbcde'
      'aabbcde'
      'aabbbde'
      'aabbde'
      'aabbbce'
      'aabbce'
      'aabbbe'
      'aabbe'
    ]

  it 'repetition in package', ->
    source = """
      package p;
      top: r{1};
      r: "R";
    """
    expect(rmutt.generate source)
      .to.equal 'R'

  it 't6 - embedded definitions', ->
    source = """
      t: (a: "0" | "1") a;
    """
    expectWithOracle source, [
      '1'
      '0'
    ]

  it 't7 - variables', ->
    source = """
      t: (a = "0" | "1") a a;
    """
    expectWithOracle source, [
      '11'
      '00'
    ]

  it 't8 - mappings', ->
    source = """
      a: b > ("0" % "a" "1" % "b");
      b: "0" | "1";
    """
    expectWithOracle source, [
      'b'
      'a'
    ]

  it 't8a - mappings', ->
    source = """
      a: "i like to eat apples and bananas" > "i" % "u";
    """
    expectWithOracle source, [
      'u luke to eat apples and bananas'
    ]

  it 't8b - mappings', ->
    source = """
      a: "i like to eat apples and bananas" > ("i" % u);
      u: "u";
    """
    expectWithOracle source, [
      'u luke to eat apples and bananas'
    ]

  it 'mapping in package', ->
    source = """
      package test;
      top: "xxx" > "x" % a;
      a: "y";
    """
    expect(rmutt.generate source)
      .to.equal 'yyy'

  it 't9 - regexes', ->
    source = """
      a: "i like to eat apples and bananas" > /[aeiou]+/oo/;
    """
    expectWithOracle source, [
      'oo lookoo too oot oopploos oond boonoonoos'
    ]

  it 't9b - regexes', ->
    source = """
      a: "i like to eat apples and bananas" > (/[aeiou]+/oo/ /loo/x/);
    """
    expectWithOracle source, [
      'oo xkoo too oot ooppxs oond boonoonoos'
    ]

  it 't9c - backreferences', ->
    source = """
      a: "a bad apple" > /a (.+) (.+)/i want the \\2s \\1ly/;
    """
    expectWithOracle source, [
      'i want the apples badly'
    ]

  it 't9 - regexes with /', ->
    source = """
      a: "a // //// b" > /[\\/]+/-/;
    """
    expect(rmutt.generate source)
      .to.equal 'a - - b'

  it 't10 - transformation chaining', ->
    source = """
      thing: name > deleteVowels > slangify > deleteVowels;
      deleteVowels: /[aeiou]//;
      slangify: "chck" % "chiggidy" "snp" % "snippidy";
      name: "check" | "chuck" | "snap" | "snipe";
    """
    expectWithOracle source, [
      'snppdy'
      'snppdy'
      'chggdy'
      'chggdy'
    ]

  it 'transformation 1', ->
    source = """
      a: "abc" > ("b" % "x");
    """
    expect(rmutt.generate source)
      .to.equal 'axc'

  it 'transformation 2', ->
    source = """
      a: "abc" > b;
      b: "b" % "x";
    """
    expect(rmutt.generate source)
      .to.equal 'axc'

  it 'transformation 3', ->
    source = """
      a: "abc" > b;
      b: "b" % "x" "c" % "y";
    """
    expect(rmutt.generate source)
      .to.equal 'axy'

  it 'packages', ->
    source = """
      package p1;

      a: b p2.a;
      b: "p1b";

      package p2;

      a: " p2a " b;
      b: "p2b";
    """
    expect(rmutt.generate source)
      .to.equal "p1b p2a p2b"

  it 't11 - packages', ->
    source = """
      package lesson;

      sentence: o " starts with the letter 'O', " greeting.o;
      o: "oatmeal" | "ogre";

      package greeting;

      s: "hello there " o;
      o: "beautiful" | "Mr. Smarty Pants";
    """
    expectWithOracle source, [
      "ogre starts with the letter 'O', Mr. Smarty Pants"
      "oatmeal starts with the letter 'O', Mr. Smarty Pants"
      "ogre starts with the letter 'O', beautiful"
      "oatmeal starts with the letter 'O', beautiful"
    ]

  it 't12 - probability multipliers', ->
    source = """
      package test;
      a: "0" 3| "1";
    """
    expectWithOracle source, [
      '1'
      '0'
      '0'
      '0'
    ]

  it 't12b - ignore no choice multiplier', ->
    source = """
      package test;
      a: "x" "y" "z" 3;
    """
    expect(rmutt.generate source)
      .to.equal 'xyz'

  it 't13 - complex mapping syntax', ->
    source = """
      a: ("a"|"b")>("a"%("0"|"zero") "b"%("1"|"one"));
    """
    expectWithOracle source, [
      'one'
      'zero'
      '1'
      '0'
    ]

  it 't14 - includes', ->
    source = """
      #include "test/t14b.rm"
      a: b;
    """
    expect(rmutt.generate source, oracle: 0)
      .to.equal 'yes!'

  it 't15 - scope qualifiers', ->
    source = """
      r: ((a="foo") a ($b="bar")) b " "
      ((c:"foo"|"bar") c ($d:"baz"|"quux") d) d "\\n";
    """
    expectWithOracle source, [
      'foobar barquuxquux\n'
      'foobar fooquuxquux\n'
      'foobar barbazquux\n'
      'foobar foobazquux\n'
      'foobar barquuxbaz\n'
      'foobar fooquuxbaz\n'
      'foobar barbazbaz\n'
      'foobar foobazbaz\n'
    ]

  it 't16 - positional arguments', ->
    source = """
      foo: (bar["thing","blah","foo"] "ie"){20};
      bar[a,b,c]: "i like " _1 " and " b " and " c;
    """
    expect(rmutt.generate source)
      .to.equal 'i like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooie'

  # more examples of non-local: math.rm, sva.rm
  # more examples of global: turing.rm, SecomPR.rm
  it 't17 - scope qualifiers: non-local', ->
    source = """
      tests:
       local.top " "
       global.top " "
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

      package global;

      top: A X;

      A: (X="1") B X;
      B: (X="2") C X;
      C: ($X="3") X;
    """

    expect(rmutt.generate source)
      .to.equal '321local.X 2213 331parent.X '

  it 't18 - imports', ->
    source = """
      top: baz.quux;

      package foo;

      bar: "quux"|"fnord";

      package baz;

      import bar from foo;

      quux: "snooby " bar;

    """
    expectWithOracle source, [
      'snooby fnord'
      'snooby quux'
    ]

  it 'multiple import', ->
    source = """
      package util;
      xuc: /a/ % "A";
      uc[text]: text > xuc;
      xtc: /^a/ % "A";
      tc[text]: text > xtc;

      package test;
      import uc, tc from util;
      top: tc["aaa"] " " uc["aaa"];
    """
    expect(rmutt.generate source, entry: 'test.top')
      .to.equal 'Aaa AAA'

  describe 'entry rule', ->

    beforeEach ->
      @source = """
        a:"A";
        b:"B";
        c:"C";
      """

    it 'first rule by default', ->
      expect(rmutt.generate @source)
        .to.equal 'A';

    it 'defined in transpilation', ->
      compiled = rmutt.compile @source, entry: 'b'
      expect(compiled())
        .to.equal 'B';

    it 'override defined in transpilation', ->
      compiled = rmutt.compile @source, entry: 'b'
      expect(compiled(entry: 'c'))
        .to.equal 'C';

  describe 'external rules', ->

    it 'handles missing transformation', ->
      source = """
        top: expr " = " (expr > calc);
        expr: "1 + 2";
      """
      expect(rmutt.generate source)
        .to.equal '1 + 2 = 1 + 2'
        # .to.throw /'calc' is not a function/

    it 'used as tramsformation', ->
      source = """
        top: expr " = " (expr > calc);
        expr: "1 + 2";
      """
      config =
        externals:
          calc: (input) ->
            (eval input).toString()

      expect(rmutt.generate source, config)
        .to.equal '1 + 2 = 3'

    it 'handles missing parameterized rule', ->
      source = """
        top: expr " = " calc[expr];
        expr: "1 + 2";
      """
      expect(-> rmutt.generate source)
        .to.throw /Missing parameterized rule/

    it 'used as parameterized rule', ->
      source = """
        top: expr " = " calc[expr, "USD"];
        expr: "1 + 2";
      """
      config =
        externals:
          calc: (input, unit) ->
            unit + ' ' + (eval input).toString()

      expect(rmutt.generate source, config)
        .to.equal '1 + 2 = USD 3'

    # TODO: #include externals.js
