#!/bin/sh

set -xe

./gen.sh
gcc gen/y.tab.c gen/lex.yy.c #-o comp
