.PHONY:  all 

all:
        coffee -b -c lib/*.coffee
clean:
        rm lib/*.js

