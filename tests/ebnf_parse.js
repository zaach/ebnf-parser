var assert = require("chai").assert;
var bnf = require("../dist/ebnf-parser-cjs-es5");
var ebnf = bnf.ebnf_parser;

function testParse(top, strings) {
    return function() {
        var expected = {
            "options": {
                "ebnf": true
            },
            "ebnf": {"top": [top]},
            "bnf": ebnf.transform({"top": [top]})
        };
        var grammar = "%ebnf\n%%\ntop : " + top + ";";
        assert.deepEqual(bnf.parse(grammar), expected);
    };
}

var tests = {
    "test idempotent transform": function() {
        var first = {
            "nodelist": [["", "$$ = [];"], ["nodelist node", "$1.push($2);"]]
        };
        var second = ebnf.transform(JSON.parse(JSON.stringify(first)));
        assert.deepEqual(second, first);
    },
    "test repeat (*) on empty string": testParse("word* EOF", ""),
    "test repeat (*) on single word": testParse("word* EOF", "oneword"),
    "test repeat (*) on multiple words": testParse("word* EOF", "multiple words"),
    "test repeat (+) on single word": testParse("word+ EOF", "oneword"),
    "test repeat (+) on multiple words": testParse("word+ EOF", "multiple words"),
    "test option (?) on empty string": testParse("word? EOF", ""),
    "test option (?) on single word": testParse("word? EOF", "oneword"),
    "test group () on simple phrase": testParse("(word word) EOF", "two words"),
    "test group () with multiple options on first option": testParse("((word word) | word) EOF", "hi there"),
    "test group () with multiple options on second option": testParse("((word word) | word) EOF", "hi"),
    "test complex expression ( *, ?, () )": testParse("(word (\",\" word)*)? EOF", ["", "hi", "hi, there"])
};

describe("EBNF parser", function () {
    for (var test in tests) {
        it(test, tests[test]);
    }
});
