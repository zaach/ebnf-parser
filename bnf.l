id                                      [a-zA-Z_](?:[a-zA-Z0-9_-]*[a-zA-Z0-9_])?
decimal_number                          [1-9][0-9]*
hex_number                              "0"[xX][0-9a-fA-F]+
BR                                      \r\n|\n|\r


%x action code
%s bnf ebnf

%options easy_keyword_rules
%options ranges

%%

<bnf,ebnf>"%%"                          this.pushState('code'); return '%%';

<ebnf>"("                               return '(';
<ebnf>")"                               return ')';
<ebnf>"*"                               return '*';
<ebnf>"?"                               return '?';
<ebnf>"+"                               return '+';

\s+                                     /* skip whitespace */
"//".*                                  /* skip comment */
"/*"(.|\n|\r)*?"*/"                     /* skip comment */
"["{id}"]"                              yytext = yytext.substr(1, yyleng - 2); return 'ALIAS';
{id}                                    return 'ID';
'"'[^"]+'"'                             yytext = yytext.substr(1, yyleng - 2); return 'STRING';
"'"[^']+"'"                             yytext = yytext.substr(1, yyleng - 2); return 'STRING';
":"                                     return ':';
";"                                     return ';';
"|"                                     return '|';
"%%"                                    this.pushState(ebnf ? 'ebnf' : 'bnf'); return '%%';
"%ebnf"                                 if (!yy.options) { yy.options = {}; } ebnf = yy.options.ebnf = true;
"%prec"                                 return 'PREC';
"%start"                                return 'START';
"%left"                                 return 'LEFT';
"%right"                                return 'RIGHT';
"%nonassoc"                             return 'NONASSOC';
"%token"                                return 'TOKEN';
"%parse-param"                          return 'PARSE_PARAM';
"%options"                              return 'OPTIONS';
"%lex"[\w\W]*?{BR}\s*"/lex"\b           return 'LEX_BLOCK';
"%"{id}[^\r\n]*                         %{ 
                                            /* ignore unrecognized decl */
                                            if (this.DEBUG || 1) console.log('ignoring unsupported option: ', yytext);
                                        %}
"<"{id}">"                              yytext = yytext.substr(1, yyleng - 2); return 'TOKEN_TYPE';
"{{"[\w\W]*?"}}"                        yytext = yytext.substr(2, yyleng - 4); return 'ACTION';
"%{"(.|\r|\n)*?"%}"                     yytext = yytext.substr(2, yytext.length - 4); return 'ACTION';
"{"                                     yy.depth = 0; this.pushState('action'); return '{';
"->".*                                  yytext = yytext.substr(2, yyleng - 2); return 'ARROW_ACTION';
{hex_number}                            yytext = parseInt(yytext, 16); return 'INTEGER';
{decimal_number}(?![xX0-9a-fA-F])       yytext = parseInt(yytext, 10); return 'INTEGER';
.                                       %{
                                            console.log("unsupported input character: ", yytext, yyloc);
                                            throw new Error("unsupported input character: " + yytext + " @ " + JSON.stringify(yyloc)); /* b0rk on bad characters */
                                        %}
<*><<EOF>>                              return 'EOF';

<action>"/*"(.|\n|\r)*?"*/"             return 'ACTION_BODY';
<action>"//".*                          return 'ACTION_BODY';
<action>"/"[^ /]*?['"{}'][^ ]*?"/"      return 'ACTION_BODY'; // regexp with braces or quotes (and no spaces)
<action>\"("\\\\"|'\"'|[^"])*\"         return 'ACTION_BODY';
<action>"'"("\\\\"|"\'"|[^'])*"'"       return 'ACTION_BODY';
<action>[/"'][^{}/"']+                  return 'ACTION_BODY';
<action>[^{}/"']+                       return 'ACTION_BODY';
<action>"{"                             yy.depth++; return '{';
<action>"}"                             if (yy.depth === 0) { this.popState(); } else { yy.depth--; } return '}';

<code>(.|\n|\r)+                        return 'CODE';

%%

