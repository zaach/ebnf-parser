
ASCII_LETTER                            [a-zA-z]
// \p{Alphabetic} already includes [a-zA-z], hence we don't need to merge
// with {UNICODE_LETTER} (though jison has code to optimize if you *did*
// include the `[a-zA-Z]` anyway):
UNICODE_LETTER                          [\p{Alphabetic}]
ALPHA                                   [{UNICODE_LETTER}_]
DIGIT                                   [\p{Number}]
WHITESPACE                              [\s\r\n\p{Separator}]
ALNUM                                   [{ALPHA}{DIGIT}]

NAME                                    [{ALPHA}](?:[{ALNUM}-]*{ALNUM})?
ID                                      [{ALPHA}]{ALNUM}*
DECIMAL_NUMBER                          [1-9][0-9]*
HEX_NUMBER                              "0"[xX][0-9a-fA-F]+
BR                                      \r\n|\n|\r
// WhiteSpace MUST NOT match CR/LF and the regex `\s` DOES, so we cannot use
// that one directly. Instead we define the {WS} macro here:
WS                                      [^\S\r\n]

// Quoted string content: support *escaped* quotes inside strings:
QUOTED_STRING_CONTENT                   (?:\\\'|\\[^\']|[^\\\'])*
DOUBLEQUOTED_STRING_CONTENT             (?:\\\"|\\[^\"]|[^\\\"])*

// Regex for matching all the possible stuff which can be placed between those `%lex.../lex` markers:
// multiple lines of arbitrary material. Use a non-gready `*?` in there to ensure that the regex
// doesn't also consume the terminating `/lex` token!
LEX_CONTENT                             {WS}*(?:{BR}[^]*?)?{BR}{WS}*



%x action code path options
%s token
%s bnf ebnf



%options easy_keyword_rules
%options ranges
%options xregexp



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
<options>\"{DOUBLEQUOTED_STRING_CONTENT}\"
                                        yytext = this.matches[1]; return 'OPTION_STRING_VALUE';   // value is always a string type
<options>\'{QUOTED_STRING_CONTENT}\'
                                        yytext = this.matches[1]; return 'OPTION_STRING_VALUE';   // value is always a string type

// Comments should be gobbled and discarded anywhere *except* the code/action blocks:
<INITIAL,ebnf,bnf,token,path,options>"//"[^\r\n]*
                                        /* skip single-line comment */
<INITIAL,ebnf,bnf,token,path,options>"/*"[^]*?"*/"
                                        /* skip multi-line comment */

<options>[^\s\r\n]+                     return 'OPTION_VALUE';
<options>{BR}{WS}+(?=\S)                /* skip leading whitespace on the next line of input, when followed by more options */
<options>{BR}                           this.popState(); return 'OPTIONS_END';
<options>{WS}+                          /* skip whitespace */

{WS}+                                   /* skip whitespace */
{BR}+                                   /* skip newlines */

"["{ID}"]"                              yytext = this.matches[1]; return 'ALIAS';
{ID}                                    return 'ID';
"$end"                                  return 'EOF_ID';
// `$eof` and `EOF` are synonyms of `$end` ('$eof' is for bison compatibility);
// this is the only place where two symbol names may map to a single symbol ID number
// and we do not want `$eof`/`EOF` to show up in the symbol tables of generated parsers
// as we use `$end` for that one!
"$eof"                                  return 'EOF_ID';
\"{DOUBLEQUOTED_STRING_CONTENT}\"
                                        yytext = this.matches[1]; return 'STRING';
\'{QUOTED_STRING_CONTENT}\'
                                        yytext = this.matches[1]; return 'STRING';
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

"%"{NAME}([^\r\n]*)                     %{
                                            /* ignore unrecognized decl */
                                            var l0 = Math.max(0, yylloc.last_column - yylloc.first_column);
                                            var l2 = 19;
                                            var l1 = Math.min(79 - 4 - l0 - l2, yylloc.first_column, 0);
                                            this.warn('EBNF: ignoring unsupported parser option:', dquote(yytext), 'while lexing in', this.topState(), 'state:\n' + indent(this.showPosition(l1, l2), 4)
                                                // , '\n', {
                                                //     remaining_input: this._input, 
                                                //     matched: this.matched,
                                                //     matches: this.matches
                                                // }
                                            );
                                            // this.pushState('options');
                                            yytext = [
                                                this.matches[1],            // {NAME}
                                                this.matches[2].trim()      // optional value/parameters
                                            ];
                                            return 'UNKNOWN_DECL';
                                        %}
"<"{ID}">"                              yytext = this.matches[1]; return 'TOKEN_TYPE';
"{{"[^]*?"}}"                           yytext = yytext.substr(2, yyleng - 4); return 'ACTION';
"%{"[^]*?"%}"                           yytext = yytext.substr(2, yyleng - 4); return 'ACTION';
"{"                                     yy.depth = 0; this.pushState('action'); return '{';
"->".*                                  yytext = yytext.substr(2, yyleng - 2).trim(); return 'ARROW_ACTION';
"→".*                                   yytext = yytext.substr(1, yyleng - 1).trim(); return 'ARROW_ACTION';
{HEX_NUMBER}                            yytext = parseInt(yytext, 16); return 'INTEGER';
{DECIMAL_NUMBER}(?![xX0-9a-fA-F])       yytext = parseInt(yytext, 10); return 'INTEGER';

<action>"/*"[^]*?"*/"                   return 'ACTION_BODY';
<action>"//"[^\r\n]*                    return 'ACTION_BODY';
<action>"/"[^ /]*?['"{}][^ ]*?"/"       return 'ACTION_BODY'; // regexp with braces or quotes (and no spaces)
<action>\"{DOUBLEQUOTED_STRING_CONTENT}\"
                                        return 'ACTION_BODY';
<action>\'{QUOTED_STRING_CONTENT}\'
                                        return 'ACTION_BODY';
<action>[/"'][^{}/"']+                  return 'ACTION_BODY';
<action>[^{}/"']+                       return 'ACTION_BODY';
<action>"{"                             yy.depth++; return '{';
<action>"}"                             if (yy.depth === 0) { this.popState(); } else { yy.depth--; } return '}';


// in the trailing CODE block, only accept these `%include` macros when
// they appear at the start of a line and make sure the rest of lexer
// regexes account for this one so it'll match that way only:
<code>[^\r\n]*(\r|\n)+                  return 'CODE';
<code>[^\r\n]+                          return 'CODE';      // the bit of CODE just before EOF...


<path>{BR}                              this.popState(); this.unput(yytext);
<path>\"{DOUBLEQUOTED_STRING_CONTENT}\"
                                        yytext = this.matches[1]; this.popState(); return 'PATH';
<path>\'{QUOTED_STRING_CONTENT}\'
                                        yytext = this.matches[1]; this.popState(); return 'PATH';
<path>{WS}+                             // skip whitespace in the line
<path>[^\s\r\n]+                        this.popState(); return 'PATH';

<*>.                                    %{
                                            /* b0rk on bad characters */
                                            var l0 = Math.max(0, yylloc.last_column - yylloc.first_column);
                                            var l2 = 39;
                                            var l1 = Math.min(79 - 4 - l0 - l2, yylloc.first_column, 0);
                                            var pos_str = this.showPosition(l1, l2);
                                            if (pos_str && pos_str[0] !== '\n') {
                                                pos_str = '\n\n       Offending input:\n' + indent(pos_str, 4);
                                            }
                                            yyerror('unsupported parser input: ' + dquote(yytext) + ' @ ' + this.describeYYLLOC(yylloc) + ' while lexing in ' + dquote(this.topState()) + ' state.' + pos_str);
                                        %}

<*><<EOF>>                              return 'EOF';

%%

function indent(s, i) {
    var a = s.split('\n');
    var pf = (new Array(i + 1)).join(' ');
    return pf + a.join('\n' + pf);
}

// properly quote and escape the given input string
function dquote(s) {
    var sq = (s.indexOf('\'') >= 0);
    var dq = (s.indexOf('"') >= 0);
    if (sq && dq) {
        s = s.replace(/"/g, '\\"');
        dq = false;
    }
    if (dq) {
        s = '\'' + s + '\'';
    }
    else {
        s = '"' + s + '"';
    }
    return s;
}

lexer.warn = function l_warn() {
    if (this.yy && this.yy.parser && typeof this.yy.parser.warn === 'function') {
        return this.yy.parser.warn.apply(this, arguments);
    } else {
        console.warn.apply(console, arguments);
    }
};

lexer.log = function l_log() {
    if (this.yy && this.yy.parser && typeof this.yy.parser.log === 'function') {
        return this.yy.parser.log.apply(this, arguments);
    } else {
        console.log.apply(console, arguments);
    }
};
