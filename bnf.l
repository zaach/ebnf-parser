
ASCII_LETTER                            [a-zA-z]
// \p{Alphabetic} already includes [a-zA-z], hence we don't need to merge with {UNICODE_LETTER}:
UNICODE_LETTER                          [\p{Alphabetic}]
ALPHA                                   [{UNICODE_LETTER}_]
DIGIT                                   [\p{Number}]
WHITESPACE                              [\s\r\n\p{Separator}]

NAME                                    [{ALPHA}](?:[{ALPHA}{DIGIT}-]*[{ALPHA}{DIGIT}])?
ID                                      [{ALPHA}][{ALPHA}{DIGIT}]*
DECIMAL_NUMBER                          [1-9][0-9]*
HEX_NUMBER                              "0"[xX][0-9a-fA-F]+
BR                                      \r\n|\n|\r
// WhiteSpace MUST NOT match CR/LF and the regex `\s` DOES, so we cannot use that one directly.
// Instead we define the {WS} macro here:
WS                                      [^\S\r\n]

// Regex for matching all the possible stuff which can be placed between those `%lex.../lex` markers:
// multiple lines of arbitrary material. Use a non-gready `*?` in there to ensure that the regex
// doesn't also consume the terminating `/lex` token!
LEX_CONTENT                             {WS}*(?:{BR}[\w\W]*?)?{BR}{WS}*


%x action code path options
%s token
%s bnf ebnf

%options easy_keyword_rules
%options ranges

%%

<token>{BR}                             this.popState();
<token>"%%"                             this.popState();
<token>";"                              this.popState();

<bnf,ebnf>"%%"                          this.pushState('code'); return '%%';

// Support bison's `%empty` (and our own alias `%epsilon`) to identify an empty rule alt:
<bnf,ebnf>"%empty"                      return 'EPSILON';
<bnf,ebnf>"%epsilon"                    return 'EPSILON';
// See also https://en.wikipedia.org/wiki/Epsilon#Glyph_variants
<bnf,ebnf>"\u0190"                      return 'EPSILON';
<bnf,ebnf>"\u025B"                      return 'EPSILON';
<bnf,ebnf>"\u03B5"                      return 'EPSILON';
<bnf,ebnf>"\u03F5"                      return 'EPSILON';

<ebnf>"("                               return '(';
<ebnf>")"                               return ')';
<ebnf>"*"                               return '*';
<ebnf>"?"                               return '?';
<ebnf>"+"                               return '+';

<options>{NAME}                         return 'NAME';
<options>"="                            return '=';
<options>\"("\\\\"|'\"'|[^"])*\"        yytext = yytext.substr(1, yytext.length - 2); return 'OPTION_VALUE';
<options>"'"("\\\\"|"\'"|[^'])*"'"      yytext = yytext.substr(1, yytext.length - 2); return 'OPTION_VALUE';

// Comments should be gobbled and discarded anywhere *except* the code/action blocks:
<INITIAL,ebnf,bnf,token,path,options>"//"[^\r\n]*
                                        /* skip single-line comment */
<INITIAL,ebnf,bnf,token,path,options>"/*"(.|\n|\r)*?"*/"
                                        /* skip multi-line comment */

<options>[^\s\r\n]+                     return 'OPTION_VALUE';
<options>{BR}+                          this.popState(); return 'OPTIONS_END';
<options>{WS}+                          /* skip whitespace */

{WS}+                                   /* skip whitespace */
{BR}+                                   /* skip newlines */

"["{ID}"]"                              yytext = yytext.substr(1, yyleng - 2); return 'ALIAS';
{ID}                                    return 'ID';
"$end"                                  return 'ID';
"$eof"                                  return 'ID';
'"'[^"]+'"'                             yytext = yytext.substr(1, yyleng - 2); return 'STRING';
"'"[^']+"'"                             yytext = yytext.substr(1, yyleng - 2); return 'STRING';
<token>[^\s\r\n]+                       return 'TOKEN_WORD';
":"                                     return ':';
";"                                     return ';';
"|"                                     return '|';
"%%"                                    this.pushState(ebnf ? 'ebnf' : 'bnf'); return '%%';
"%ebnf"                                 if (!yy.options) { yy.options = {}; } ebnf = yy.options.ebnf = true;
"%debug"                                if (!yy.options) { yy.options = {}; } yy.options.debug = true; return 'DEBUG';
"%parser-type"                          return 'PARSER_TYPE';
"%prec"                                 return 'PREC';
"%start"                                return 'START';
"%left"                                 return 'LEFT';
"%right"                                return 'RIGHT';
"%nonassoc"                             return 'NONASSOC';
"%token"                                this.pushState('token'); return 'TOKEN';
"%parse-param"                          return 'PARSE_PARAM';
"%options"                              this.pushState('options'); return 'OPTIONS';
"%lex"{LEX_CONTENT}"/lex"               %{
                                            // remove the %lex../lex wrapper and return the pure lex section:
                                            yytext = this.matches[1];
                                            return 'LEX_BLOCK';
                                        %}

"%code"                                 return 'INIT_CODE';
"%import"                               return 'IMPORT';
<INITIAL,ebnf,bnf,code>"%include"
                                        this.pushState('path'); return 'INCLUDE';

"%"{NAME}[^\r\n]*                       %{
                                            /* ignore unrecognized decl */
                                            console.warn('ignoring unsupported parser option: ', yytext, ' while lexing in ', this.topState(), ' state');
                                            return 'UNKNOWN_DECL';
                                        %}
"<"{ID}">"                              yytext = yytext.substr(1, yyleng - 2); return 'TOKEN_TYPE';
"{{"[\w\W]*?"}}"                        yytext = yytext.substr(2, yyleng - 4); return 'ACTION';
"%{"(.|\r|\n)*?"%}"                     yytext = yytext.substr(2, yytext.length - 4); return 'ACTION';
"{"                                     yy.depth = 0; this.pushState('action'); return '{';
"->".*                                  yytext = yytext.substr(2, yyleng - 2); return 'ARROW_ACTION';
{HEX_NUMBER}                            yytext = parseInt(yytext, 16); return 'INTEGER';
{DECIMAL_NUMBER}(?![xX0-9a-fA-F])       yytext = parseInt(yytext, 10); return 'INTEGER';
.                                       %{
                                            throw new Error("unsupported input character: " + yytext + " @ " + JSON.stringify(yylloc)); /* b0rk on bad characters */
                                        %}
<*><<EOF>>                              return 'EOF';

<action>"/*"(.|\n|\r)*?"*/"             return 'ACTION_BODY';
<action>"//"[^\r\n]*                    return 'ACTION_BODY';
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


<path>{BR}                              this.popState(); this.unput(yytext);
<path>"'"[^\r\n]+"'"                    yytext = yytext.substr(1, yyleng - 2); this.popState(); return 'PATH';
<path>'"'[^\r\n]+'"'                    yytext = yytext.substr(1, yyleng - 2); this.popState(); return 'PATH';
<path>{WS}+                             // skip whitespace in the line
<path>[^\s\r\n]+                        this.popState(); return 'PATH';


%%

