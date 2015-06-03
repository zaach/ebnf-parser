/* EBNF grammar spec */

%lex

id                                      [a-zA-Z_](?:[a-zA-Z0-9_-]*[a-zA-Z0-9_])?
decimal_number                          [1-9][0-9]*
hex_number                              "0"[xX][0-9a-fA-F]+

%%

\s+                       /* skip whitespace */
{id}                      return 'SYMBOL';
"["{id}"]"                yytext = yytext.substr(1, yyleng - 2); return 'ALIAS';
"'"[^']*"'"               return 'SYMBOL';
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
  | handle expression_suffix
    { $handle.push($expression_suffix); }
  ;

expression_suffix
  : expression suffix ALIAS
    { $$ = ['xalias', $suffix, $expression, $ALIAS]; }
  | expression suffix
    { if ($suffix) $$ = [$suffix, $expression]; else $$ = $expression; }
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
