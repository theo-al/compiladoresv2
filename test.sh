#!/bin/sh

./build.sh

set -e

echo "compilando parasi -> c"

echo "main.parasi:"
./a.out main.parasi > main.out.c
if [ $? -eq 0 ]; then echo "pass"; fi

cd testes/
for file in *.parasi; do
    if [ -f "$file" ]; then
        echo "$file:";

        ../a.out "$file" > out/"$file".c
        if [ $? -eq 0 ]; then echo "pass"; fi
    fi 
done

set +e

echo ""
echo "compilando c -> exe"

cp ../mem.h out/
for file in *; do 
    if [ -f "$file" ]; then
        echo "$file:";

        gcc out/"$file".c -o out/"$file".out -Wno-unused-result
        if [ $? -eq 0 ]; then echo "pass"; fi
    fi 
done

cd ..
echo "main.out.c:"
gcc main.out.c -o main.out -Wno-unused-result
if [ $? -eq 0 ]; then echo "pass"; fi