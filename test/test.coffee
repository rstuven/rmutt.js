require 'coffee-script'
rmutt = require '../lib/rmutt2'
expect = require('chai').expect

describe 'rmutt', ->

  it 't10 - transformation chaining', ->
    source = """
    thing: name > r1 > r2 > r3;
    r1: /[aeiou]//;
    r2: "snp" % "snippidy";
    r3: /[aeiou]/x/;
    name: "snape" , "snap";
    """
    rules = rmutt.parse source, index: 0
    # console.log rules

  it 'transformation 1', ->
    source = """
    a: "abc" > ("b" % "x");
    """
    expect(rmutt.generate source, index: 0).to.equal 'axc'

  it 'transformation 2', ->
    source = """
    a: "abc" > b;
    b: "b" % "x";
    """
    expect(rmutt.generate source, index: 0).to.equal 'axc'

  it 'transformation 3', ->
    source = """
    a: "abc" > b;
    b: "b" % "x" "c" % "y";
    """
    expect(rmutt.generate source, index: 0).to.equal 'axy'

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
    expect(rmutt.generate source, len: 4, index: 0).to.equal 'yelled patiently at you'
    expect(rmutt.generate source, len: 4, index: 32).to.equal 'ate patiently with you'
    expect(rmutt.generate source, len: 4, index: 64).to.equal 'waited impatiently with me'

  it 't0', ->
    source = """
    s: (character = name, position) character " said, 'I am " character ", so nice to meet you.'";
    name: title " " firstName " " lastName;
    title: "Dr.", "Mr.", "Mrs.", "Ms";
    firstName: "Nancy", "Reginald", "Edna", "Archibald";
    lastName: "McPhee", "Eaton-Hogg", "Worthingham";
    position: "the butler", "the chauffeur";
    """
    expect(rmutt.generate source, index: 0).to.equal "Dr. Nancy McPhee said, 'I am Dr. Nancy McPhee, so nice to meet you.'"
    expect(rmutt.generate source, index: 1).to.equal "the chauffeur said, 'I am the chauffeur, so nice to meet you.'"

  it 't1 - random selection', ->
    source = """
    t: "0"|"1"|"2";
    """
    expect(rmutt.generate source, index: 0).to.equal '0'
    expect(rmutt.generate source, index: 1).to.equal '1'
    expect(rmutt.generate source, index: 2).to.equal '2'

  it 't2 - recursion', ->
    source = """
    t: "0"|a;
    a: "1";
    """
    expect(rmutt.generate source, index: 0).to.equal '0'
    expect(rmutt.generate source, index: 1).to.equal '1'

  it 't3 - anonymous rules', ->
    source = """
    t: "a" ("b"|"c") "d";
    """
    expect(rmutt.generate source, index: 0).to.equal 'abd'
    expect(rmutt.generate source, index: 1).to.equal 'acd'

  it 't4 - nested anonymous rules', ->
    source = """
    t: "a" ("b"|("c"|"d"));
    """
    source = rmutt.parse source # optimization
    expect(rmutt.generate source, len: 2, index: 1).to.equal 'ab'
    expect(rmutt.generate source, len: 2, index: 2).to.equal 'ac'
    expect(rmutt.generate source, len: 2, index: 3).to.equal 'ad'

  it 't5 - repetition', ->
    source = """
    t: "a"{2} "b"{2,3} "c"? "d"* "e"+;
    """
    source = rmutt.parse source # optimization
    results = [
      'aabbe'
      'aabbbcdee'
      'aabbddeee'
      'aabbbcdddeeee'
      'aabbddddeeeee'
      'aabbbcddddde'
      'aabbee'
      'aabbbcdeee'
      'aabbddeeee'
    ]
    for result, index in results
      expect(rmutt.generate source, index: index).to.equal result

  it 't6 - embedded definitions', ->
    source = """
    t: (a: "0" | "1") a;
    """
    expect(rmutt.generate source, index: 0).to.equal '0'
    expect(rmutt.generate source, index: 1).to.equal '1'

  it 't7 - variables', ->
    source = """
    t: (a = "0" | "1") a a;
    """
    expect(rmutt.generate source, index: 0).to.equal '00'
    expect(rmutt.generate source, index: 1).to.equal '11'

  it 't8 - mappings', ->
    source = """
    a: b > ("0" % "a" "1" % "b");
    b: "0" | "1";
    """
    expect(rmutt.generate source, index: 0).to.equal 'a'
    expect(rmutt.generate source, index: 1).to.equal 'b'

  it 't8a - mappings', ->
    source = """
    a: "i like to eat apples and bananas" > "i" % "u";
    """
    expect(rmutt.generate source, index: 0).to.equal 'u luke to eat apples and bananas'

  it 't8b - mappings', ->
    source = """
    a: "i like to eat apples and bananas" > ("i" % u);
    u: "u";
    """
    expect(rmutt.generate source, index: 0).to.equal 'u luke to eat apples and bananas'

  it 't9 - regexes', ->
    source = """
    a: "i like to eat apples and bananas" > /[aeiou]+/oo/;
    """
    expect(rmutt.generate source, index: 0).to.equal 'oo lookoo too oot oopploos oond boonoonoos'

  it 't9b - regexes', ->
    source = """
    a: "i like to eat apples and bananas" > (/[aeiou]+/oo/ /loo/x/);
    """
    expect(rmutt.generate source, index: 0).to.equal 'oo xkoo too oot ooppxs oond boonoonoos'

  it 't10 - transformation chaining', ->
    source = """
    thing: name > deleteVowels > slangify > deleteVowels;
    deleteVowels: /[aeiou]//;
    slangify: "chck" % "chiggidy" "snp" % "snippidy";
    name: "check" | "chuck" | "snap" | "snipe";
    """
    expect(rmutt.generate source, index: 0).to.equal 'chggdy'
    expect(rmutt.generate source, index: 1).to.equal 'chggdy'
    expect(rmutt.generate source, index: 2).to.equal 'snppdy'
    expect(rmutt.generate source, index: 3).to.equal 'snppdy'

  it 'packages', ->
    source = """
    package p1;

    a: b p2.a;
    b: "p1b";

    package p2;

    a: " p2a " b;
    b: "p2b";

    """
    expect(rmutt.generate source, index: 0).to.equal "p1b p2a p2b"

  it 't11 - packages', ->
    source = """
    package lesson;

    sentence: o " starts with the letter 'O', " greeting.o;
    o: "oatmeal" | "ogre";

    package greeting;

    s: "hello there " o;
    o: "beautiful" | "Mr. Smarty Pants";
    """
    expect(rmutt.generate source, len: 2, index: 0).to.equal "oatmeal starts with the letter 'O', beautiful"
    expect(rmutt.generate source, len: 2, index: 2).to.equal "oatmeal starts with the letter 'O', Mr. Smarty Pants"
    expect(rmutt.generate source, len: 2, index: 1).to.equal "ogre starts with the letter 'O', beautiful"
    expect(rmutt.generate source, len: 2, index: 3).to.equal "ogre starts with the letter 'O', Mr. Smarty Pants"

  it 't12 - probability multipliers', ->
    source = """
    a: "0" 3| "1";
    """
    expect(rmutt.generate source, index: 0).to.equal '0'
    expect(rmutt.generate source, index: 1).to.equal '0'
    expect(rmutt.generate source, index: 2).to.equal '0'
    expect(rmutt.generate source, index: 3).to.equal '1'

  it 't13 - complex mapping syntax', ->
    source = """
    a: ("a"|"b")>("a"%("0"|"zero") "b"%("1"|"one"));
    """
    source = rmutt.parse source # optimization
    expect(rmutt.generate source, index: 0, len: 3).to.equal '0'
    expect(rmutt.generate source, index: 1, len: 3).to.equal 'zero'
    expect(rmutt.generate source, index: 2, len: 3).to.equal '0'
    expect(rmutt.generate source, index: 3, len: 3).to.equal 'zero'
    expect(rmutt.generate source, index: 4, len: 3).to.equal '1'
    expect(rmutt.generate source, index: 5, len: 3).to.equal '1'
    expect(rmutt.generate source, index: 6, len: 3).to.equal 'one'
    expect(rmutt.generate source, index: 7, len: 3).to.equal 'one'

  it 't14 - includes', ->
    source = """
    #include "test/t14b.rm"
    a: b;
    """
    expect(rmutt.generate source, index: 0).to.equal 'yes!'

  it 't15 - scope qualifiers', ->
    source = """
    r: ((a="foo") a ($b="bar")) b " "
    ((c:"foo"|"bar") c ($d:"baz"|"quux") d) d "\\n";
    """
    source = rmutt.parse source # optimizon

    expect(rmutt.generate source, len: 2, index: 0).to.equal 'foobar foobazquux\n'
    expect(rmutt.generate source, len: 2, index: 1).to.equal 'foobar barbazquux\n'
    expect(rmutt.generate source, len: 2, index: 2).to.equal 'foobar fooquuxquux\n'
    expect(rmutt.generate source, len: 2, index: 3).to.equal 'foobar barquuxquux\n'
    expect(rmutt.generate source, len: 2, index: 4).to.equal 'foobar foobazbaz\n'

  it 't16 - positional arguments', ->
    source = """
    foo: (bar["thing","blah","foo"] "ie"){20};
    bar[a,b,c]: "i like " _1 " and " b " and " c;
    """
    expect(rmutt.generate source, index: 0, logRules: true).to.equal 'i like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooiei like thing and blah and fooie'

  # more examples of non-local: math.rm, sva.rm
  # more examples of global: turing.rm, SecomPR.rm
  it 't17 - scope qualifiers: non-local', ->
    source = """
    tests:
     local.top " "
     global.top " "
     non_local.top " "
    ;

    package local;

    top: A X;

    A: (X="1") B X;
    B: (X="2") C X;
    C: (X="3") X;

    package non_local;

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

    expect(rmutt.generate source, index: 0).to.equal '321local.X 2213 331non_local.X '

  it 't18 - imports', ->
    source = """
    top: baz.quux;

    package foo;

    bar: "quux"|"fnord";

    package baz;

    import bar from foo;

    quux: "snooby " bar;

    """
    expect(rmutt.generate source, index: 0).to.equal 'snooby quux'
    expect(rmutt.generate source, index: 1).to.equal 'snooby fnord'
