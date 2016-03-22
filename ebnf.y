/* EBNF grammar spec */

%lex

NAME                                    [a-zA-Z_](?:[a-zA-Z0-9_-]*[a-zA-Z0-9_])?
ID                                      [a-zA-Z_][a-zA-Z0-9_]*
DECIMAL_NUMBER                          [1-9][0-9]*
HEX_NUMBER                              "0"[xX][0-9a-fA-F]+
BR                                      \r\n|\n|\r
// quoted string content: support *escaped* quotes inside strings:
QUOTED_STRING_CONTENT                   (?:\\"'"|(?!"'").)*
DOUBLEQUOTED_STRING_CONTENT             (?:\\'"'|(?!'"').)*


%%

\s+                       /* skip whitespace */
{ID}                      return 'SYMBOL';
"$end"                    return 'SYMBOL';
"$eof"                    return 'SYMBOL';
"["{ID}"]"                yytext = yytext.substr(1, yyleng - 2); return 'ALIAS';

// Support bison's `%empty` (and our own alias `%epsilon`) to identify an empty rule alt:
"%empty"                  return 'EPSILON';
"%epsilon"                return 'EPSILON';

// Stringified tokens are always `'`-surrounded by the bnf.y grammar unless the token
// itself contain an `'`.
//
// Note: EBNF grammars would barf a hairball or work in very mysterious ways if someone
// ever decided that the combo of quotes, i.e. `'"` would be a legal token in their grammar,
// e.g. `rule: A '\'"' B`.
//
// And, yes, we assume that the `bnf.y` parser is our regular input source, so we may
// be a bit stricter here in what we lex than in the userland-facing `bnf.l` lexer.
"'"{QUOTED_STRING_CONTENT}"'"
                          return 'SYMBOL';
'"'{DOUBLEQUOTED_STRING_CONTENT}'"'
                          return 'SYMBOL';
"."                       return 'SYMBOL';

"("                       return '(';
")"                       return ')';
"*"                       return '*';
"?"                       return '?';
"|"                       return '|';
"+"                       return '+';
<<EOF>>                   return 'EOF';

/lex

%start production

%%

production
  : handle EOF
    { return $handle; }
  ;

handle_list
  : handle
    { $$ = [$handle]; }
  | handle_list '|' handle
    { $handle_list.push($handle); }
  ;

handle
  :
    { $$ = []; }
  | EPSILON                       
    // %epsilon may only be used to signal this is an empty rule alt; 
    // hence it can only occur by itself 
    // (with an optional action block, but no alias what-so-ever).
    { $$ = []; }
  | rule
    { $$ = $rule; }
  ;

rule
  : expression_suffixed
    { $$ = [$expression_suffixed]; }
  | rule expression_suffixed
    { $rule.push($expression_suffixed); }
  ;

expression_suffixed
  : expression suffix ALIAS
    { $$ = ['xalias', $suffix, $expression, $ALIAS]; }
  | expression suffix
    {
      if ($suffix) {
        $$ = [$suffix, $expression];
      } else {
        $$ = $expression;
      }
    }
  ;

expression
  : SYMBOL
    { $$ = ['symbol', $SYMBOL]; }
  | '(' handle_list ')'
    { $$ = ['()', $handle_list]; }
  ;

suffix
  :
  | '*'
  | '?'
  | '+'
  ;
