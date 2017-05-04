# This lets us use the dependency node modules with executable parts to them as
# if they were in $PATH like usual system programs.
export PATH := $(shell npm bin):$(PATH)

SRC = $(shell find src -name "*.ls" -type f | sort)
LIB = $(SRC:src/%.ls=lib/%.js)

all: $(LIB)

lib/%.js: src/%.ls
	@mkdir -p lib/
	lsc --output lib --bare --compile "$<"

clean:
	@rm -rf lib/

test: all
	@lsc test.ls

test-readme: all readme.markdown
	@txm readme.markdown

test-docs: all doc/how-macros-work.markdown doc/basics-reference.markdown
	@txm doc/how-macros-work.markdown
	@txm doc/basics-reference.markdown

test-all: all test test-readme test-docs

.PHONY: all clean test test-readme test-docs test-all
