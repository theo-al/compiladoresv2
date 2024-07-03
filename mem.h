typedef union {
    int i; float f; void* p;
} reg;

static reg mem[TAM_MEM];

reg load(int ptr) {
    return mem[ptr];
}
void store(int ptr, reg val) {
    mem[ptr] = val;
}