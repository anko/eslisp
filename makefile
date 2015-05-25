export PATH := node_modules/.bin:$(PATH)

SRC = $(shell find src -name "*.ls" -type f | sort)
LIB = $(SRC:src/%.ls=lib/%.js)

all: $(LIB)

lib/%.js: src/%.ls
	@mkdir -p lib/
	lsc --output lib --bare --compile "$<"

clean:
	rm -rf lib/

test:
	lsc test.ls

# `all` because txm requires the executable to be built
test-readme: all readme.markdown
	txm readme.markdown

.PHONY: default all clean
