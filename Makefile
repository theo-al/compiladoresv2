CC_ARGS = -g -Wno-parentheses -Wunused-variable #-Wall -Wextra


parasi: gen/y.tab.c gen/lex.yy.c
	gcc $(CC_ARGS) $+ -o $@ 

gen/y.tab.c:
	yacc -d in.y -Wcounterexamples
	mkdir -p gen/
	mv y.tab.c gen/
	mv y.tab.h gen/

gen/lex.yy.c:
	lex in.l
	mkdir -p gen/
	mv lex.yy.c gen/


.PHONY:
test: parasi
	./test.sh

.PHONY:
clean:
	-rm parasi
	-rm main.parasi.c
	-rm main.parasi.out
	-rm -r testes/out/
