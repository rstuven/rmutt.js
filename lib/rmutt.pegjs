{

  function extractList(list, index) {
    var result = new Array(list.length), i
    for (i = 0; i < list.length; i++) {
      result[i] = list[i][index]
    }
    return result
  }

  function buildList(first, rest, index) {
    return [first].concat(extractList(rest, index))
  }

  function buildListLast(heads, index, last) {
    return extractList(heads, index).concat(last)
  }

}


Grammar
  = Statement+

Statement
  = _ match:(Include / StatementBlock / Comment) _ {
    return match
  }

Comment
  = '//' NonLineTerminator* LineTerminator

/*
 * Each Statement either adds a Rule or changes the package
 */
StatementBlock
  = match:(Package / Import / Rule) _ ';' {
    return match
  }

Package
  = 'package' _ match:Identifier {
    return { type: 'Package', name: match }
  }

Import
  = 'import' _ rules:Imports _ 'from' _ package:Identifier {
    return { type: 'Import', rules: rules, package: package }
  }

Imports
  = heads:(Identifier _ ',' _)+ last:Identifier {
    return buildListLast(heads, 0, last)
  }
  / match:Identifier {
    return [match]
  }

Include
  = '#include' _ '"' match:Path '"' {
    return { type: 'Include', path: match }
  }

Path
  = match:[a-z0-9/_\-.]+ {
    return match.join('')
  }

/*
 * A Rule consists of a label and a list of Choices, among other things
 */
Rule
  = name:Identifier _ '[' _ args:ArgumentNames _ ']' _ ':' _ expr:Body {
    return { type: 'Rule', name: name, expr: expr, args: args }
  }
  / name:Identifier _ ':' _ expr:Body {
    return { type: 'Rule', name: name, expr: expr }
  }
  / name:Identifier _ '=' _ expr:Body {
    return { type: 'Assignment', name: name, expr: expr }
  }

ArgumentNames
  = first:ArgumentName rest:(_ ',' _ ArgumentName)* {
    return buildList(first, rest, 3)
  }

ArgumentName
  = Identifier


/*
 * Body is a list of terms or (at least two) choices, one of which will be chosen
 */
Body
  = Choice
  / Terms

/*
 * A Choice is a list of Terms
 */
Choice
  = choices:(_ MultipliedTerms? _ [,|] _)+ last:MultipliedTerms? {
    var items = buildListLast(choices, 1, last)
    return { type: 'Choice', items: items }
  }

MultipliedTerms
  = term:Terms _ multiplier:Integer {
    return { type: 'Multiplier', term: term, multiplier: multiplier }
  }
  / Terms

Terms
  = first:QualifiedTerm _ rest:(Terms / QualifiedTerm) {
    // flatten nested items
    var items = [first]
    if (rest.type == 'Terms') {
      items = items.concat(rest.items)
    } else {
      items.push(rest)
    }
    return { type: 'Terms', items: items }
  }
  / match:QualifiedTerm {
    return { type: 'Terms', items: [match] }
  }

/*
 * A QualifiedTerm is a term with a repetition or transformation qualifier
 */
QualifiedTerm
  = term:Term !([?*+{] / _ '>') {
    return term
  }
  / term:Term '?' {
    return { type: 'Repetition', expr: term, range: { min: 0, max: 1 } }
  }
  / term:Term '*' {
    return { type: 'Repetition', expr: term, range: { min: 0, max: 5 } }
  }
  / term:Term '+' {
    return { type: 'Repetition', expr: term, range: { min: 1, max: 5 } }
  }
  / term:Term '{' _ min:Integer _ ',' _ max:Integer _ '}' {
    return { type: 'Repetition', expr: term, range: { min: min, max: max } }
  }
  / term:Term '{' _ times:Integer _ '}' {
    return { type: 'Repetition', expr: term, range: { min: times, max: times } }
  }
  / expr:Term _ '>' _ func:QualifiedTerm {
    return { type: 'Transformation',  expr: expr, func: func }
  }

Term
  = RuleCall
  / '(' _ match:Body _ ')' { return match }
  / '(' _ match:ScopedRule _ ')' { return match }
  / Mapping
  / RegExpMapping
  / String

Mapping
  = search:String _ '%' _ replace:QualifiedTerm {
    return {
      type: 'Mapping',
      search: search,
      replace: replace
    }
  }

RegExpMapping
  = '/' search:RegularExpressionBody '/' replace:Chars '/' {
    return {
      type: 'Mapping',
      search: { type: 'String', value: search },
      replace: { type: 'String', value: replace }
    }
  }

ScopedRule
  = rule:Rule {
    rule.scope = 'local'
    return rule
  }
  / '^' rule:Rule {
    rule.scope = 'parent'
    return rule
  }
  / '$' rule:Rule {
    rule.scope = 'global'
    return rule
  }

RuleCall
  = name:RuleName _ '[' _ args:Arguments _ ']' {
    return { type: 'RuleCall', name: name, args: args }
  }
  / name:RuleName {
    return { type: 'RuleCall', name: name }
  }

RuleName
  = PackageRuleName
  / Identifier

PackageRuleName
  = match:(Identifier '.' Identifier) {
    return match.join('')
  }

Arguments
  = first:Argument rest:(_ ',' _ Argument)* {
    return buildList(first, rest, 3)
  }

Argument
  = Terms

String
  = match:StringLiteral {
    return { type: 'String', value: match }
  }

Chars
  = match:[a-z0-9, .!'\-\\]i* {
    return match.join('')
  }

Integer
  = match:[0-9]+ {
    return +match.join('')
  }

Identifier
  = start:[_a-z]i rest:[a-z0-9\-_]i* {
    return start + rest.join('')
  }

_
//  = ' '* (Comment / LineTerminator?)
  = (' ' / '\t' / LineTerminator)*

__
  = ' '+ / LineTerminator+



/*
 * https://github.com/dmajda/pegjs/blob/master/examples/javascript.pegjs
 */


RegularExpressionBody
  = char_:RegularExpressionFirstChar chars:RegularExpressionChars {
      return char_ + chars;
  }

RegularExpressionChars
  = chars:RegularExpressionChar* { return chars.join(""); }

RegularExpressionFirstChar
  = ![*\\/[] char_:RegularExpressionNonTerminator { return char_; }
  / RegularExpressionBackslashSequence
  / RegularExpressionClass

RegularExpressionChar
  = ![\\/[] char_:RegularExpressionNonTerminator { return char_; }
  / RegularExpressionBackslashSequence
  / RegularExpressionClass

/*
 * This rule contains an error in the specification: "NonTerminator" instead of
 * "RegularExpressionNonTerminator".
 */
RegularExpressionBackslashSequence
  = "\\" char_:RegularExpressionNonTerminator { return "\\" + char_; }

RegularExpressionNonTerminator
  = !LineTerminator char_:SourceCharacter { return char_; }

RegularExpressionClass
  = "[" chars:RegularExpressionClassChars "]" { return "[" + chars + "]"; }

RegularExpressionClassChars
  = chars:RegularExpressionClassChar* { return chars.join(""); }

RegularExpressionClassChar
  = ![\]\\] char_:RegularExpressionNonTerminator { return char_; }
  / RegularExpressionBackslashSequence

LineTerminator
  = [\n\r\u2028\u2029]

NonLineTerminator
  = [^\n\r\u2028\u2029]

LineTerminatorSequence "end of line"
  = "\n"
  / "\r\n"
  / "\r"
  / "\u2028" // line separator
  / "\u2029" // paragraph separator

SourceCharacter
  = .

StringLiteral "string"
  = parts:('"' DoubleStringCharacters? '"' / "'" SingleStringCharacters? "'") {
      return parts[1];
    }

DoubleStringCharacters
  = chars:DoubleStringCharacter+ { return chars.join(""); }

SingleStringCharacters
  = chars:SingleStringCharacter+ { return chars.join(""); }

DoubleStringCharacter
  = !('"' / "\\" / LineTerminator) char_:SourceCharacter { return char_;     }
  / "\\" sequence:EscapeSequence                         { return sequence;  }
  / LineContinuation

SingleStringCharacter
  = !("'" / "\\" / LineTerminator) char_:SourceCharacter { return char_;     }
  / "\\" sequence:EscapeSequence                         { return sequence;  }
  / LineContinuation

LineContinuation
  = "\\" sequence:LineTerminatorSequence { return sequence; }

EscapeSequence
  = CharacterEscapeSequence
  / "0" !DecimalDigit { return "\0"; }
  / HexEscapeSequence
  / UnicodeEscapeSequence

CharacterEscapeSequence
  = SingleEscapeCharacter
  / NonEscapeCharacter

SingleEscapeCharacter
  = char_:['"\\bfnrtv] {
      return char_
        .replace("b", "\b")
        .replace("f", "\f")
        .replace("n", "\n")
        .replace("r", "\r")
        .replace("t", "\t")
        .replace("v", "\x0B") // IE does not recognize "\v".
    }

NonEscapeCharacter
  = (!EscapeCharacter / LineTerminator) char_:SourceCharacter { return char_; }

EscapeCharacter
  = SingleEscapeCharacter
  / DecimalDigit
  / "x"
  / "u"

HexEscapeSequence
  = "x" h1:HexDigit h2:HexDigit {
      return String.fromCharCode(parseInt("0x" + h1 + h2));
    }

UnicodeEscapeSequence
  = "u" h1:HexDigit h2:HexDigit h3:HexDigit h4:HexDigit {
      return String.fromCharCode(parseInt("0x" + h1 + h2 + h3 + h4));
    }

HexDigit
  = [0-9a-fA-F]

DecimalDigits
  = DecimalDigit+

DecimalDigit
  = [0-9]
