#!/bin/sh

yacc -d in.y -Wcounterexamples
lex in.l

if [ ! -d "gen/" ]; then
    mkdir gen/
fi

mv y.tab.c gen/
mv y.tab.h gen/
mv lex.yy.c gen/
