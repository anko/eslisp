export PATH := node_modules/.bin:$(PATH)

default: all

SRC = $(shell find src -name "*.ls" -type f | sort)
LIB = $(SRC:src/%.ls=lib/%.js)

lib/%.js: src/%.ls
	@mkdir -p lib/
	lsc --output lib --bare --compile "$<"

.PHONY: default all clean

all: $(LIB)

clean:
	rm -rf lib/
