
all: install build test

install:
	npm install

build:
	node ./node_modules/.bin/jison bnf.y bnf.l
	mv bnf.js parser.js

test:
	node tests/all-tests.js

