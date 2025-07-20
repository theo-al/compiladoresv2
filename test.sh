#!/bin/sh

section() {
    echo ""
    echo "$1"
    set $2
}
announce() {
    echo "$1:"
    echo -n "    ";
}
result() {
    if [ $1 -eq 0 ]; then
        echo "pass"; 
    else
        echo -n "    ";
        echo "failed";
    fi
}

section "teste principal" -e

announce "main.parasi"
./parasi main.parasi > main.parasi.c
result $?

announce "main.parasi.c"
gcc -I. "main.parasi.c" -o "main.parasi.out" -Wno-unused-result
result $?

section "compilando parasi -> c" -e
mkdir -p testes/out

for file in testes/*.parasi; do
    name=$(basename "$file")

    announce "$name";
    ./parasi "$file" > "testes/out/$name.c"
    result $?
done


section "compilando c -> exe" +e
mkdir -p testes/out

for file in testes/out/*.c; do
    name=$(basename "$file")

    announce "$name";
    gcc -I. "$file" -o "testes/out/$name.out" -Wno-unused-result
    result $?
done
