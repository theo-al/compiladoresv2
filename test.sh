#!/bin/sh

./build.sh

set -e

echo "main.parasi:"
./a.out < main.parasi > main.out.c
if [ $? -eq 0 ]; then echo "pass"; fi

cd testes/
for file in *; do 
    if [ -f "$file" ]; then
        echo "$file"":";
        
        ../a.out < "$file" > out/"$file".c
        if [ $? -eq 0 ]; then echo "pass"; fi
    fi 
done


#./a.out < testes/for.parasi   > testes/for.parasi.out
#./a.out < testes/if.parasi    > testes/if.parasi.out
#./a.out < testes/print.parasi > testes/print.parasi.out
#./a.out < testes/var.parasi   > testes/var.parasi.out
#./a.out < testes/scan.parasi  > testes/scan.parasi.out
