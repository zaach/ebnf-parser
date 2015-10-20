id                                      [a-zA-Z_](?:[a-zA-Z0-9_-]*[a-zA-Z0-9_])?
decimal_number                          [1-9][0-9]*
hex_number                              "0"[xX][0-9a-fA-F]+
BR                                      \r\n|\n|\r


%x action code path 
%s token
%s bnf ebnf

%options easy_keyword_rules
%options ranges

%%

<token>\r|\n                            this.popState();
<token>"%%"                             this.popState();
<token>";"                              this.popState();

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
<token>[^\s\r\n]+                       return 'TOKEN_WORD';
":"                                     return ':';
";"                                     return ';';
"|"                                     return '|';
"%%"                                    this.pushState(ebnf ? 'ebnf' : 'bnf'); return '%%';
"%ebnf"                                 if (!yy.options) { yy.options = {}; } ebnf = yy.options.ebnf = true;
"%debug"                                if (!yy.options) { yy.options = {}; } yy.options.debug = true;
"%parser-type"                          return 'PARSER_TYPE';
"%prec"                                 return 'PREC';
"%start"                                return 'START';
"%left"                                 return 'LEFT';
"%right"                                return 'RIGHT';
"%nonassoc"                             return 'NONASSOC';
"%token"                                this.pushState('token'); return 'TOKEN';
"%parse-param"                          return 'PARSE_PARAM';
"%options"                              return 'OPTIONS';
"%lex"[\w\W]*?{BR}\s*"/lex"\b           return 'LEX_BLOCK';

<INITIAL,ebnf,bnf,code>"%include"       this.pushState('path'); return 'INCLUDE';

"%"{id}[^\r\n]*                         %{ 
                                            /* ignore unrecognized decl */
                                            console.warn('ignoring unsupported parser option: ', yytext, ' while lexing in ', this.topState(), ' state');
                                        %}
"<"{id}">"                              yytext = yytext.substr(1, yyleng - 2); return 'TOKEN_TYPE';
"{{"[\w\W]*?"}}"                        yytext = yytext.substr(2, yyleng - 4); return 'ACTION';
"%{"(.|\r|\n)*?"%}"                     yytext = yytext.substr(2, yytext.length - 4); return 'ACTION';
"{"                                     yy.depth = 0; this.pushState('action'); return '{';
"->".*                                  yytext = yytext.substr(2, yyleng - 2); return 'ARROW_ACTION';
{hex_number}                            yytext = parseInt(yytext, 16); return 'INTEGER';
{decimal_number}(?![xX0-9a-fA-F])       yytext = parseInt(yytext, 10); return 'INTEGER';
.                                       %{
                                            //console.log("unsupported input character: ", yytext, yylloc);
                                            throw new Error("unsupported input character: " + yytext + " @ " + JSON.stringify(yylloc)); /* b0rk on bad characters */
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


// in the trailing CODE block, only accept these `%include` macros when they appear at the start of a line
// and make sure the rest of lexer regexes account for this one so it'll match that way only:
<code>[^\r\n]*(\r|\n)+                  return 'CODE';
<code>[^\r\n]+                          return 'CODE';      // the bit of CODE just before EOF...


<path>[\r\n]                            this.popState(); this.unput(yytext);
<path>"'"[^\r\n]+"'"                    yytext = yytext.substr(1, yyleng - 2); this.popState(); return 'PATH';
<path>\"[^\r\n]+\"                      yytext = yytext.substr(1, yyleng - 2); this.popState(); return 'PATH';
<path>\s+                               // skip whitespace in the line
<path>[^\s\r\n]+                        this.popState(); return 'PATH';


%%

