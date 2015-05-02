rmutt = require '..'
expect = require('chai').expect

expectc = (source, expected) ->
  compiled = rmutt.compile source
  for result, index in expected.reverse()
    expect(compiled oracle: index).to.equal result

# TODO: empty grammar test
# TODO: undefined config test
# TODO: config.entryRule test
# TODO: rename expectc

describe 'rmutt', ->

  examplesDir = __dirname + '/../examples/'

  it.only 'example', ->

    file = 'directions.rm'

    fs = require 'fs'
    source = fs.readFileSync examplesDir + file, 'utf8'
    # console.log source

    console.time('compile')
    compiled = rmutt.compile source, workingDirectory: examplesDir
    console.timeEnd('compile')
    # console.log compiled.toString()

    console.time('generate')
    output = compiled()
    console.timeEnd('generate')

    console.log()
    console.log output

  it 'mapping in package', ->
    source = """
      package test;
      top: "xxx" > "x" % a;
      a: "y";
    """
    expect(rmutt.generate source).to.equal 'yyy'

  it 'rule call from parameter', ->
    source = """
      package test;
      top: a[b["c"]];
      a[p]:p;
      b[p]:p;
    """
    expect(rmutt.generate source).to.equal 'c'

  it 'more than one dash in rule identifier', ->
    source = 'a-b-c:"x";'
    expect(rmutt.generate source).to.equal 'x'

  it 'repetition in package', ->
    source = """
      package p;
      top: r{1};
      r: "R";
    """
    # console.log (rmutt.compile source).toString()
    expect(rmutt.generate source, oracle: 0).to.equal 'R'

  it 'multiple import', ->
    source = """
      #include "util.rm"
      import uc, tc from util;
      top: tc["aaa"] " " uc["aaa"];
    """
    expect(rmutt.generate source, oracle: 1, workingDirectory: examplesDir).to.equal 'Aaa AAA'

  it 'empty choice', ->
    source = """
      soldOut: | |  |    "<b>SOLD OUT</b>" | |  |;
    """
    compiled = rmutt.compile source
    expect(compiled oracle: 0).to.equal ''
    expect(compiled oracle: 1).to.equal ''
    expect(compiled oracle: 2).to.equal ''
    expect(compiled oracle: 3).to.equal '<b>SOLD OUT</b>'
    expect(compiled oracle: 4).to.equal ''

  it 'repeat with variety', ->
    source = """
      top: a{2};
      a: "x", "y";
    """
    expect(rmutt.generate source, oracle: 1).to.equal 'yx'

  it 'terms parameter', ->
    source = """
      top: a[b c];
      a[x]: x;
    """
    expect(rmutt.generate source).to.equal 'bc'

  it 'paramater has local precedence in package', ->
    source = """
    package wtf;
    top: a['x'];
    a[p]: p;
    p: 'y';
    """
    expect(rmutt.generate source).to.equal 'x'

  it 't10 - transformation chaining', ->
    source = """
    thing: name
    > r1 > r2 > r3;
    r1: /[aeiou]//;
    r2: "snp" % "snippidy";
    r3: /[aeiou]/x/;
    name: "snape" , "snap";
    """
    compiled  = rmutt.compile source, oracle: 0
    # console.log rules

  it 'transformation 1', ->
    source = """
    a: "abc" > ("b" % "x");
    """
    expect(rmutt.generate source, oracle: 0).to.equal 'axc'

  it 'transformation 2', ->
    source = """
    a: "abc" > b;
    b: "b" % "x";
    """
    expect(rmutt.generate source, oracle: 0).to.equal 'axc'

  it 'transformation 3', ->
    source = """
    a: "abc" > b;
    b: "b" % "x" "c" % "y";
    """
    expect(rmutt.generate source, oracle: 0).to.equal 'axy'

describe 'rmutt', ->

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
    expect(compiled oracle: 0).to.equal 'ate patiently with you'
    expect(compiled oracle: 200).to.equal 'waited patiently for me'
    expect(compiled oracle: 400).to.equal 'yelled impatiently at you'

  it 't0', ->
    source = """
    s: (character = name, position) character " said, 'I am " character ", so nice to meet you.'";
    name: title " " firstName " " lastName;
    title: "Dr.", "Mr.", "Mrs.", "Ms";
    firstName: "Nancy", "Reginald", "Edna", "Archibald";
    lastName: "McPhee", "Eaton-Hogg", "Worthingham";
    position: "the butler", "the chauffeur";
    """
    compiled = rmutt.compile source
    expect(compiled oracle: 1).to.equal "the butler said, 'I am the butler, so nice to meet you.'"
    expect(compiled oracle: 0).to.equal "Dr. Nancy McPhee said, 'I am Dr. Nancy McPhee, so nice to meet you.'"

  it 't1 - random selection', ->
    source = """
    t: "0"|"1"|"2";
    """
    compiled = rmutt.compile source
    expect(compiled oracle: 0).to.equal '0'
    expect(compiled oracle: 1).to.equal '1'
    expect(compiled oracle: 2).to.equal '2'

  # TODO: Circular reference?
  # TODO: Check original rmutt test
  it 't2 - recursion', ->
    source = """
    t: "0"|a;
    a: "1";
    """
    compiled = rmutt.compile source
    expect(compiled oracle: 0).to.equal '0'
    expect(compiled oracle: 1).to.equal '1'

  it 't3 - anonymous rules', ->
    source = """
    t: "a" ("b"|"c") "d";
    """
    compiled = rmutt.compile source
    expect(compiled oracle: 0).to.equal 'abd'
    expect(compiled oracle: 1).to.equal 'acd'

  it 't4 - nested anonymous rules', ->
    source = """
    t: "a" ("b"|("c"|"d"));
    """
    expectc source, [
      'ad'
      'ab'
      'ac'
      'ab'
    ]

  it 't5 - repetition', ->
    source = """
    t: "a"{2} "b"{2,3} "c"? "d"* "e"+;
    """
    expectc source, [
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

  it 't6 - embedded definitions', ->
    source = """
    t: (a: "0" | "1") a;
    """
    compiled = rmutt.compile source
    expect(compiled oracle: 0).to.equal '0'
    expect(compiled oracle: 1).to.equal '1'

  it 't7 - variables', ->
    source = """
    t: (a = "0" | "1") a a;
    """
    compiled = rmutt.compile source
    expect(compiled oracle: 0).to.equal '00'
    expect(compiled oracle: 1).to.equal '11'

  it 't8 - mappings', ->
    source = """
    a: b > ("0" % "a" "1" % "b");
    b: "0" | "1";
    """
    compiled = rmutt.compile source
    expect(compiled oracle: 0).to.equal 'a'
    expect(compiled oracle: 1).to.equal 'b'

  it 't8a - mappings', ->
    source = """
    a: "i like to eat apples and bananas" > "i" % "u";
    """
    expect(rmutt.generate source, oracle: 0).to.equal 'u luke to eat apples and bananas'

  it 't8b - mappings', ->
    source = """
    a: "i like to eat apples and bananas" > ("i" % u);
    u: "u";
    """
    expect(rmutt.generate source, oracle: 0).to.equal 'u luke to eat apples and bananas'

  it 't9 - regexes', ->
    source = """
    a: "i like to eat apples and bananas" > /[aeiou]+/oo/;
    """
    expect(rmutt.generate source, oracle: 0).to.equal 'oo lookoo too oot oopploos oond boonoonoos'

  it 't9b - regexes', ->
    source = """
    a: "i like to eat apples and bananas" > (/[aeiou]+/oo/ /loo/x/);
    """
    expect(rmutt.generate source, oracle: 0).to.equal 'oo xkoo too oot ooppxs oond boonoonoos'

  it 't9c - backreferences', ->
    source = """
    a: "a bad apple" > /a (.+) (.+)/i want the \\2s \\1ly/;
    """
    expect(rmutt.generate source, oracle: 0).to.equal 'i want the apples badly'

  it 't10 - transformation chaining', ->
    source = """
    thing: name > deleteVowels > slangify > deleteVowels;
    deleteVowels: /[aeiou]//;
    slangify: "chck" % "chiggidy" "snp" % "snippidy";
    name: "check" | "chuck" | "snap" | "snipe";
    """
    expect(rmutt.generate source, oracle: 3).to.equal 'snppdy'
    expect(rmutt.generate source, oracle: 2).to.equal 'snppdy'
    expect(rmutt.generate source, oracle: 1).to.equal 'chggdy'
    expect(rmutt.generate source, oracle: 0).to.equal 'chggdy'

  it 'packages', ->
    source = """
    package p1;

    a: b p2.a;
    b: "p1b";

    package p2;

    a: " p2a " b;
    b: "p2b";

    """
    expect(rmutt.generate source, oracle: 0).to.equal "p1b p2a p2b"

  it 't11 - packages', ->
    source = """
    package lesson;

    sentence: o " starts with the letter 'O', " greeting.o;
    o: "oatmeal" | "ogre";

    package greeting;

    s: "hello there " o;
    o: "beautiful" | "Mr. Smarty Pants";
    """
    compiled = rmutt.compile source
    expect(compiled oracle: 3).to.equal "ogre starts with the letter 'O', Mr. Smarty Pants"
    expect(compiled oracle: 2).to.equal "oatmeal starts with the letter 'O', Mr. Smarty Pants"
    expect(compiled oracle: 1).to.equal "ogre starts with the letter 'O', beautiful"
    expect(compiled oracle: 0).to.equal "oatmeal starts with the letter 'O', beautiful"

  it 't12 - probability multipliers', ->
    source = """
    package test;
    a: "0" 3| "1";
    """
    compiled = rmutt.compile source
    expect(compiled oracle: 3).to.equal '1'
    expect(compiled oracle: 2).to.equal '0'
    expect(compiled oracle: 1).to.equal '1'
    expect(compiled oracle: 0).to.equal '0'

  it 't13 - complex mapping syntax', ->
    source = """
    a: ("a"|"b")>("a"%("0"|"zero") "b"%("1"|"one"));
    """
    compiled = rmutt.compile source
    expect(compiled oracle: 6).to.equal 'one'
    expect(compiled oracle: 4).to.equal '1'
    expect(compiled oracle: 1).to.equal 'zero'
    expect(compiled oracle: 0).to.equal '0'

    # TODO: Expected order:
    # oracle:3 one
    # oracle:2 zero
    # oracle:1 1
    # oracle:0 0


  it 't14 - includes', ->
    source = """
    #include "test/t14b.rm"
    a: b;
    """
    expect(rmutt.generate source, oracle: 0).to.equal 'yes!'

  it 't15 - scope qualifiers', ->
    source = """
    r: ((a="foo") a ($b="bar")) b " "
    ((c:"foo"|"bar") c ($d:"baz"|"quux") d) d "\\n";
    """
    compiled = rmutt.compile source
    expect(compiled oracle: 7).to.equal 'foobar barquuxquux\n'
    expect(compiled oracle: 6).to.equal 'foobar fooquuxquux\n'
    expect(compiled oracle: 5).to.equal 'foobar barbazquux\n'
    expect(compiled oracle: 4).to.equal 'foobar foobazquux\n'
    expect(compiled oracle: 3).to.equal 'foobar barquuxbaz\n'
    expect(compiled oracle: 2).to.equal 'foobar fooquuxbaz\n'
    expect(compiled oracle: 1).to.equal 'foobar barbazbaz\n'
    expect(compiled oracle: 0).to.equal 'foobar foobazbaz\n'

  it 't16 - positional arguments', ->
    source = """
    foo: (bar["thing","blah","foo"] "ie"){20};
    bar[a,b,c]: "i like " _1 " and " b " and " c;
    """
    expect(rmutt.generate source).to.equal 'i like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooie'

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

    expect(rmutt.generate source).to.equal '321local.X 2213 331parent.X '

  it 't18 - imports', ->
    source = """
    top: baz.quux;

    package foo;

    bar: "quux"|"fnord";

    package baz;

    import bar from foo;

    quux: "snooby " bar;

    """
    compiled = rmutt.compile source
    expect(compiled oracle: 1).to.equal 'snooby fnord'
    expect(compiled oracle: 0).to.equal 'snooby quux'

  describe 'custom functions', ->

    it 'handles missing transformation', ->
      source = """
      top: expr " = " (expr > calc);
      expr: "1 + 2";
      """
      expect(-> rmutt.generate source).to.throw /'calc' is not a function/

    it 'uses as tramsformation', ->
      source = """
      top: expr " = " (expr > calc);
      expr: "1 + 2";
      """
      config =
        functions:
          calc: (input) ->
            (eval input).toString()

      expect(rmutt.generate source, config).to.equal '1 + 2 = 3'

    it 'handles missing rule or function', ->
      source = """
      top: expr " = " calc[expr];
      expr: "1 + 2";
      """
      expect(-> rmutt.generate source).to.throw /Missing parameterized rule or custom function/

    it 'uses as parameterized rule', ->
      source = """
      top: expr " = " calc[expr, "USD"];
      expr: "1 + 2";
      """
      config =
        functions:
          calc: (input, unit) ->
            unit + ' ' + (eval input).toString()

      expect(rmutt.generate source, config).to.equal '1 + 2 = USD 3'

    # TODO: #include functions.js
