#!/bin/sh

export CC_ARGS="-g -Wno-parentheses -Wunused-variable"

set -xe

./gen.sh
gcc gen/y.tab.c gen/lex.yy.c $CC_ARGS #-Wall -Wextra #-o comp
