typedef union {
    int i; float f; void* p;
} reg;

static reg mem[TAM_MEM];
static reg sp = { .i = sizeof(mem)-1 }; //registrador de "ponteiro" da pilha (ver se deixar como um uint normal depois)

reg load(int ptr) {
    return mem[ptr];
}
void store(int ptr, reg val) {
    mem[ptr] = val;
}