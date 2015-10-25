/* EBNF grammar spec */

%lex

id                                      [a-zA-Z_](?:[a-zA-Z0-9_-]*[a-zA-Z0-9_])?
decimal_number                          [1-9][0-9]*
hex_number                              "0"[xX][0-9a-fA-F]+

%%

\s+                       /* skip whitespace */
{id}                      return 'SYMBOL';
"["{id}"]"                yytext = yytext.substr(1, yyleng - 2); return 'ALIAS';

// Stringified tokens are always `'`-surrounded by the bnf.y grammar unless the token
// itself contain an `'`. 
//
// Note: EBNF grammars would barf a hairball or work in very mysterious ways if someone
// ever decided that the combo of quotes, i.e. `'"` would be a legal token in their grammar,
// e.g. `rule: A '\'"' B`.
//
// And, yes, we assume that the `bnf.y` parser is our regular input source, so we may
// be a bit stricter here in what we lex than in the userland-facing `bnf.l` lexer.
"'"[^']+"'"               return 'SYMBOL';
"'"[^']+"'"               return 'SYMBOL';
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
  | handle expression_suffixed
    { $handle.push($expression_suffixed); }
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
