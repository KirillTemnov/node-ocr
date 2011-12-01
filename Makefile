.PHONY:  all clean

all:
	coffee -b -c lib/*.coffee
clean:
	rm lib/*.js

