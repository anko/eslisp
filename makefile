export PATH := node_modules/.bin:$(PATH)

SRC = $(shell find src -name "*.ls" -type f | sort)
LIB = $(SRC:src/%.ls=lib/%.js)

all: $(LIB)

lib/%.js: src/%.ls
	@mkdir -p lib/
	lsc --output lib --bare --compile "$<"

clean:
	rm -rf lib/

.PHONY: default all clean
