
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
QUOTED_STRING_CONTENT                   (?:\\\'|\\[^\']|[^\\\'\r\n])*
DOUBLEQUOTED_STRING_CONTENT             (?:\\\"|\\[^\"]|[^\\\"\r\n])*
// backquoted ES6/ES2017 string templates MAY span multiple lines:
ES2017_STRING_CONTENT                   (?:\\\`|\\[^\`]|[^\\\`])*

// Regex for matching all the possible stuff which can be placed between those `%lex.../lex` markers:
// multiple lines of arbitrary material. Use a non-gready `*?` in there to ensure that the regex
// doesn't also consume the terminating `/lex` token!
LEX_CONTENT                             {WS}*(?:{BR}[^]*?)?{BR}{WS}*



%x action code path options option_values
%s token
%s bnf ebnf



%options easy_keyword_rules
%options ranges
%options xregexp



%%

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
<action>"}"                             if (yy.depth === 0) { 
                                            this.popState(); 
                                        } else { 
                                            yy.depth--; 
                                        } 
                                        return '}';

<token>{BR}                             this.popState();
<token>"%%"                             this.popState();
<token>";"                              this.popState();

<bnf,ebnf>"%%"                          this.pushState('code'); 
                                        return '%%';

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
<options>"="                            this.pushState('option_values'); 
                                        return '=';
<option_values>{

\"{DOUBLEQUOTED_STRING_CONTENT}\"
                                        yytext = unescQuote(this.matches[1], /\\"/g); 
                                        this.popState(); 
                                        return 'OPTION_STRING_VALUE';   // value is always a string type
\'{QUOTED_STRING_CONTENT}\'
                                        yytext = unescQuote(this.matches[1], /\\'/g); 
                                        this.popState(); 
                                        return 'OPTION_STRING_VALUE';   // value is always a string type
\`{ES2017_STRING_CONTENT}\`
                                        yytext = unescQuote(this.matches[1], /\\`/g); 
                                        this.popState(); 
                                        return 'OPTION_STRING_VALUE';   // value is always a string type

}

// Comments should be gobbled and discarded anywhere *except* the code/action blocks:
<INITIAL,ebnf,bnf,token,path,options,option_values>"//"[^\r\n]*
                                        /* skip single-line comment */
<INITIAL,ebnf,bnf,token,path,options,option_values>"/*"[^]*?"*/"
                                        /* skip multi-line comment */

<option_values>[^\s\r\n]+               this.popState(); 
                                        return 'OPTION_VALUE';

<options>{BR}{WS}+(?=\S)                /* skip leading whitespace on the next line of input, when followed by more options */
<options>{BR}                           this.popState(); return 'OPTIONS_END';
<options,option_values>{WS}+            /* skip whitespace */

{WS}+                                   /* skip whitespace */
{BR}+                                   /* skip newlines */

"["{ID}"]"                              yytext = this.matches[1]; return 'ALIAS';
{ID}                                    return 'ID';
{NAME}                                  return 'NAME';
"$end"                                  return 'EOF_ID';
// `$eof` and `EOF` are synonyms of `$end` ('$eof' is for bison compatibility);
// this is the only place where two symbol names may map to a single symbol ID number
// and we do not want `$eof`/`EOF` to show up in the symbol tables of generated parsers
// as we use `$end` for that one!
"$eof"                                  return 'EOF_ID';

\"{DOUBLEQUOTED_STRING_CONTENT}\"       %{
                                            yytext = unescQuote(this.matches[1], /\\"/g);
                                            return 'STRING';
                                        %}
\'{QUOTED_STRING_CONTENT}\'             %{
                                            yytext = unescQuote(this.matches[1], /\\'/g);
                                            return 'STRING';
                                        %}

<token>[^\s\r\n]+                       return 'TOKEN_WORD';
":"                                     return ':';
";"                                     return ';';
"|"                                     return '|';
"%%"                                    this.pushState(yy.ebnf ? 'ebnf' : 'bnf'); return '%%';
"%ebnf"                                 yy.ebnf = true; return 'EBNF';
"%debug"                                return 'DEBUG';
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
<INITIAL,ebnf,bnf,code>"%include"       this.pushState('path'); 
                                        return 'INCLUDE';

"%"{NAME}([^\r\n]*)                     %{
                                            /* ignore unrecognized decl */
                                            this.warn(rmCommonWS`
                                                EBNF: ignoring unsupported parser option ${dquote(yytext)}
                                                while lexing in ${dquote(this.topState())} state.

                                                  Erroneous area:
                                                ` + this.prettyPrintRange(this, yylloc));
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


// in the trailing CODE block, only accept these `%include` macros when
// they appear at the start of a line and make sure the rest of lexer
// regexes account for this one so it'll match that way only:
<code>[^\r\n]*(\r|\n)+                  return 'CODE';
<code>[^\r\n]+                          return 'CODE';      // the bit of CODE just before EOF...


<path>{BR}                              this.popState(); this.unput(yytext);

<path>\"{DOUBLEQUOTED_STRING_CONTENT}\"
                                        yytext = unescQuote(this.matches[1]);
                                        this.popState();
                                        return 'PATH';
<path>\'{QUOTED_STRING_CONTENT}\'
                                        yytext = unescQuote(this.matches[1]);
                                        this.popState();
                                        return 'PATH';

<path>{WS}+                             // skip whitespace in the line
<path>[^\s\r\n]+                        this.popState();
                                        return 'PATH';


// detect and report unterminated string constants ASAP
// for 'action', 'options', but also for other lexer conditions:
//
// these error catching rules fix https://github.com/GerHobbelt/jison/issues/13
<action>\"                              yyerror(rmCommonWS`
                                            unterminated string constant in lexer rule action block.

                                              Erroneous area:
                                            ` + this.prettyPrintRange(this, yylloc));
                                        return 'error';
<action>\'                              yyerror(rmCommonWS`
                                            unterminated string constant in lexer rule action block.

                                              Erroneous area:
                                            ` + this.prettyPrintRange(this, yylloc));
                                        return 'error';
<action>\`                              yyerror(rmCommonWS`
                                            unterminated string constant in lexer rule action block.

                                              Erroneous area:
                                            ` + this.prettyPrintRange(this, yylloc));
                                        return 'error';

<option_values>\"                       yyerror(rmCommonWS`
                                            unterminated string constant in %options entry.

                                              Erroneous area:
                                            ` + this.prettyPrintRange(this, yylloc));
                                        return 'error';
<option_values>\'                       yyerror(rmCommonWS`
                                            unterminated string constant in %options entry.

                                              Erroneous area:
                                            ` + this.prettyPrintRange(this, yylloc));
                                        return 'error';
<option_values>\`                       yyerror(rmCommonWS`
                                            unterminated string constant in %options entry.

                                              Erroneous area:
                                            ` + this.prettyPrintRange(this, yylloc));
                                        return 'error';

<*>\"                                   var rules = (this.topState() === 'macro' ? 'macro\'s' : this.topState());
                                        yyerror(rmCommonWS`
                                            unterminated string constant  encountered while lexing
                                            ${rules}.

                                              Erroneous area:
                                            ` + this.prettyPrintRange(this, yylloc));
                                        return 'error';
<*>\'                                   var rules = (this.topState() === 'macro' ? 'macro\'s' : this.topState());
                                        yyerror(rmCommonWS`
                                            unterminated string constant  encountered while lexing
                                            ${rules}.

                                              Erroneous area:
                                            ` + this.prettyPrintRange(this, yylloc));
                                        return 'error';
<*>\`                                   var rules = (this.topState() === 'macro' ? 'macro\'s' : this.topState());
                                        yyerror(rmCommonWS`
                                            unterminated string constant  encountered while lexing
                                            ${rules}.

                                              Erroneous area:
                                            ` + this.prettyPrintRange(this, yylloc));
                                        return 'error';


<*>.                                    %{
                                            /* b0rk on bad characters */
                                            yyerror(rmCommonWS`
                                                unsupported parser input: ${dquote(yytext)}
                                                while lexing in ${dquote(this.topState())} state.
                                                
                                                  Erroneous area:
                                                ` + this.prettyPrintRange(this, yylloc));
                                        %}

<*><<EOF>>                              return 'EOF';

%%

function indent(s, i) {
    var a = s.split('\n');
    var pf = (new Array(i + 1)).join(' ');
    return pf + a.join('\n' + pf);
}

// unescape a string value which is wrapped in quotes/doublequotes
function unescQuote(str) {
    str = '' + str;
    var a = str.split('\\\\');
    a = a.map(function (s) {
        return s.replace(/\\'/g, "'").replace(/\\"/g, '"');
    });
    str = a.join('\\\\');
    return str;
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

// tagged template string helper which removes the indentation common to all
// non-empty lines: that indentation was added as part of the source code
// formatting of this lexer spec file and must be removed to produce what
// we were aiming for.
//
// Each template string starts with an optional empty line, which should be
// removed entirely, followed by a first line of error reporting content text,
// which should not be indented at all, i.e. the indentation of the first
// non-empty line should be treated as the 'common' indentation and thus
// should also be removed from all subsequent lines in the same template string.
//
// See also: https://developer.mozilla.org/en/docs/Web/JavaScript/Reference/Template_literals
function rmCommonWS(strings, ...values) {
    // as `strings[]` is an array of strings, each potentially consisting
    // of multiple lines, followed by one(1) value, we have to split each
    // individual string into lines to keep that bit of information intact.
    var src = strings.map(function splitIntoLines(s) {
        return s.split('\n');
    });
    // fetch the first line of content which is expected to exhibit the common indent:
    // that would be the SECOND line of input, always, as the FIRST line won't
    // have any indentation at all!
    var s0 = '';
    for (var i = 0, len = src.length; i < len; i++) {
        if (src[i].length > 1) {
            s0 = src[i][1];
            break;
        }
    }
    var indent = s0.replace(/^(\s+)[^\s]*.*$/, '$1');
    // we assume clean code style, hence no random mix of tabs and spaces, so every
    // line MUST have the same indent style as all others, so `length` of indent
    // should suffice, but the way we coded this is stricter checking when we apply
    // a find-and-replace regex instead:
    var indent_re = new RegExp('^' + indent);

    // process template string partials now:
    for (var i = 0, len = src.length; i < len; i++) {
        // start-of-lines always end up at index 1 and above (for each template string partial):
        for (var j = 1, linecnt = src[i].length; j < linecnt; j++) {
            src[i][j] = src[i][j].replace(indent_re, '');
        }
    }

    // now merge everything to construct the template result:
    var rv = [];
    for (var i = 0, len = src.length, klen = values.length; i < len; i++) {
        rv.push(src[i].join('\n'));
        // all but the last partial are followed by a template value:
        if (i < klen) {
            rv.push(values[i]);
        }
    }
    var sv = rv.join('');
    return sv;
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
