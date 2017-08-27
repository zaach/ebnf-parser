
ifeq ($(wildcard ../../lib/cli.js),) 
	ifeq ($(wildcard ./node_modules/.bin/jison),) 
		echo "### FAILURE: Make sure you have run 'make prep' before as the jison compiler is unavailable! ###"
	else
		JISON = sh node_modules/.bin/jison
	endif
else 
	JISON = node $(wildcard ../../lib/cli.js)
endif 



all: build test

prep: npm-install

npm-install:
	npm install

build:
	node __patch_version_in_js.js

	$(JISON) bnf.y bnf.l
	mv bnf.js parser.js

	$(JISON) ebnf.y
	mv ebnf.js transform-parser.js

test:
	node_modules/.bin/mocha tests/


# increment the XXX <prelease> number in the package.json file: version <major>.<minor>.<patch>-<prelease>
bump:
	npm version --no-git-tag-version prerelease

git-tag:
	node -e 'var pkg = require("./package.json"); console.log(pkg.version);' | xargs git tag

publish:
	npm run pub 






clean:
	-rm -f parser.js
	-rm -f transform-parser.js
	-rm -f bnf.js
	-rm -f ebnf.js
	-rm -rf node_modules/
	-rm -f package-lock.json

superclean: clean
	-find . -type d -name 'node_modules' -exec rm -rf "{}" \;





.PHONY: all prep npm-install build test clean superclean bump git-tag publish
