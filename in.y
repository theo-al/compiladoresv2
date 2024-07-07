%{
/*TODO: 
- usar um offset (SP) na hora de acessar a memória (pelo menos) nas funções. seria um "registrador"
- permitir mais de uma função por programa (terminar funcs)
- chamada de função;
    - tecnicamente colocar todos os registradores na pilha depois passar os argumentos via função de c mesmo;
    | mas pode ser colocar os argumentos na pilha e dentro da função puxar (não colocaria mais os argumentos dentro da assinatura no c gerado);
    | ou fazer do jeito que tá, tá encaminhado pra só puxar as entradas pra registradores novos, colocar eles dentro da chamada, e usar tudo como c.
    - falta resetar a tabela de simbolos a cada função (não sei se em funcs ou func) junto com os registradores que já tão resetando.
        - fazendo isso tem que salvar o número máximo de registradores usados (numa global aqui provavelmente).
- achava que tinha mais.
- colocar o pct type certo nas coisas pra ele me dar erros melhores
- melhorar os erros pro usuário
- esquecer pilha (fazer na memória normal), só manter o SP (mudar pra base)
*/
/*
IDEIA: fazer goto com um switch, um PC, e um caso pra cada linha
*/

int yylex();

/* C declarations used in actions */
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <assert.h>

extern FILE* yyin;
#if 0
#  define DEBUG
#  define YYDEBUG 1
#endif

#define TAM_MEM 2048

static struct { char* nome; int tipo; } tabela_simb[TAM_MEM/2];

int acessa_tab(char*, bool);
#define tab_idx(nome) acessa_tab(nome, false)
#define reset_tab()   acessa_tab(NULL, true)
#define num_vars()    acessa_tab(NULL, false)

int acessa_reg(bool, int);
#define prox_reg()    acessa_reg(false, 1)
#define reset_reg()   acessa_reg(true, 0)
#define get_reg()     acessa_reg(false, 0)

typedef struct {
    int ret;
    int num_args;
    int* args;
} ass;

static struct {char* nome; ass sig;}  tabela_func[TAM_MEM/2];

int registra_func(char*, ass);
int func_idx(char* nome);
#define consulta_sig(nome) (tabela_func[func_idx(nome)].sig);

int get_loc();

char* typ2fmt(int tipo);
char* typ2reg(int tipo);
char* typ2c(int tipo);

#define yyerror(fmt, ...) fprintf(stderr, fmt "\n", ##__VA_ARGS__)
#define UNREACHABLE(...)  assert(!"unreacheable");

#define ALLOC(sz)            calloc(1, sz)
#define alloc(sz)            ALLOC(100 + sz)

#define streql(s1, s2)       (strcmp(s1, s2) == 0)
#define str2cpy(buf, s1, s2) strcat(strcpy(buf, s1), s2)
#define str2dup(s1, s2)      str2cpy(ALLOC(strlen(s1) + strlen(s2)), s1, s2)
#define strdup(s)            strcpy(ALLOC(strlen(s)), s)

#define spf_begin(buf_name)   { spf_set_buf(buf_name);
#define spf_set_buf(buf_name) char* s = buf_name
#define spf_cat(fmt, ...)     s += sprintf(s, fmt, ##__VA_ARGS__)
#define spf_end()             }

%}

/* Yacc definitions */
%union {
    char* str; //remover e usar s no lugar
    struct {
        char* s;
        enum { VOID = 0, INT, FLT, STR } t; //guardar embaixo junto com o apropriado
        enum { ID, LIT, EXPR, FUNC } u; //renomear pra d ou algo mais descritivo
        union { // TODO: fazer um substruct pra cada tipo desses em vez de uma subunion 
            int r;
            int p;
            struct {
                char* nome;
                void* a; //ou tipar ou inlinear ass aqui
                char* b;
                int num_regs;
            };
        };
    } rhs; //tirar nome
}

%start prog
%token cmd_print cmd_scan cmd_exit cmd_for cmd_if cmd_do cmd_end cmd_let cmd_return
%token typ_int typ_flt typ_str assign
%token <str> val_id val_int val_flt val_str op_arit

%type <str> prog func bloco decls decl stmts stmt assn exp exp_ term 
%type <rhs> assinatura

%%

/* descriptions of expected inputs     corresponding actions (in C) */

prog : funcs  {
    printf("%s", $<rhs.b>1);
}
;
funcs : func  {
          $<rhs>$ = $<rhs>1;
      }
      //| func funcs {
      //    $$ = $1 + $2
      //}
      ;

func : decls assinatura bloco  {
    ass*  sig  = $<rhs.a>2;
    char* nome = $<rhs.nome>2;
    int num_args = sig->num_args;
    int num_reg  = get_reg();
    char* buf = alloc(100 + num_reg*30 + sig->num_args*8 + sig->num_args*10 + strlen($3));

    spf_begin(buf);
        spf_cat("#include <stdio.h>\n"
                "#include <stdlib.h>\n"
                "\n"
                "#define TAM_MEM %d\n"
                "#include \"mem.h\"\n"
                "\n", TAM_MEM);

        if (streql(nome, "ini")) spf_cat("int main () {\n");
        else {
            int arg;
            
            spf_cat("%s %s (", typ2c(sig->ret), nome);
            for (int i = 0; i < num_args-1; i++) {
                spf_cat("%s a%d, ", typ2c(arg = sig->args[i]), i+1);
                assert(arg);
            }
            if (arg = sig->args[num_args-1])
                spf_cat("%s a%d", typ2c(arg), num_args);

            spf_cat(") {\n");
        }
        {
            spf_cat("/*\n%s*/\n", $1);
            spf_cat("reg ");
            for (int i = 1; i < num_reg; i++) {
                spf_cat("r%d, ", i);
            } spf_cat("r%d;\n", num_reg);
        }
        spf_cat("\n"
                "%s\n"
                "\n", $<rhs.s>3);

        if (streql(nome, "ini")) spf_cat("return 0;\n");

        spf_cat("}\n");
    spf_end();

    reset_reg();
    reset_tab();

    $<rhs.u>$ = FUNC;
    $<rhs.nome>$ = nome;
    $<rhs.a>$ = sig;
    $<rhs.b>$ = buf;
}

;


assinatura : _tipo val_id _tipos {
                    ass* sig = $<rhs.a>3;
                    sig->ret = $<rhs.t>1,
                    
                    $<rhs.u>$ = FUNC;
                    $<rhs.nome>$ = $<rhs.s>2;
                    $<rhs.a>$    = sig;
               }
           ;


bloco   : cmd_do stmts cmd_end  { $$ = $2; }
        ;

stmts   : /*epsilon*/       { $$ = ""; }
        | stmt ';' stmts    {
                char* buf = alloc(5 + strlen($1) + strlen($3));
                sprintf(buf, "%s\n"
                             "%s", $1, $3);
                $$ = buf;
            }
        ;
stmt    : assn               { $$ = $1; }
        | cmd_exit           { $$ = "exit(0);"; }
        | cmd_print exp      {
                int r1 = $<rhs.r>2;
                char* tfmt = typ2fmt($<rhs.t>2);
                char* treg = typ2reg($<rhs.t>2);
                char* tc =   typ2c($<rhs.t>2);
                char* buf = alloc(100 + strlen($2));

                sprintf(buf, "%s\n"
                             "printf(\"%s\\n\", (%s)r%d.%s);", $2, tfmt, tc, r1, treg);
                $$ = buf;
            }
        | cmd_scan val_id    {
                char* nome = $2;
                int   idx  = tab_idx(nome);
                int   tipo = tabela_simb[idx].tipo;
                char* tfmt = typ2fmt(tipo);
                char* treg = typ2reg(tipo);

                assert($<rhs.u>2 == ID);

                char* buf = alloc(50 + strlen($2));
                if (tipo != STR) {
                    sprintf(buf, "scanf(\"%s\", &mem[%d/*%s*/].%s);\n",
                                          tfmt,      idx,nome, treg);
                } else {
                    sprintf(buf, "scanf(\"%s\", (char*)mem[%d/*%s*/].p);\n",
                                          tfmt,            idx,nome);
                }
                $$ = buf;
            }
        | cmd_if exp bloco   {
                int loc = get_loc();
                char* buf = alloc(10*4 + strlen($2) + strlen($3));
                int   r1 = $<rhs.r>2;
                char* t1 = typ2reg($<rhs.t>2);

                spf_begin(buf);
                    spf_cat("%s\n", $2);
                    spf_cat("if (!r%d.%s) goto out%d;\n", r1, t1, loc);
                    spf_cat("%s\n", $3);
                    spf_cat("out%d:\n", loc);
                    //spf_cat("\n");
                spf_end();

                $$ = buf;
            }
        | cmd_for exp bloco  {
                int loc = get_loc();
                char* buf = alloc(10*5 + strlen($2) + strlen($3));
                int   r1 = $<rhs.r>2;
                char* t1 = typ2reg($<rhs.t>2);

                spf_begin(buf);
                    spf_cat("loop%d:\n", loc);
                    spf_cat("%s\n", $2);
                    spf_cat("if (!r%d.%s) goto out%d;\n", r1, t1, loc);
                    spf_cat("%s", $3);
                    spf_cat("goto loop%d;\n", loc);
                    spf_cat("out%d:\n", loc);
                    //spf_cat("\n");
                spf_end();

                $$ = buf;
            }
        | ';'                {;}
        ;

decls : /*epsilon*/     { $$ = ""; }
      | decl ';' decls  { $$ = str2dup($1, $3); }
      ;
decl : cmd_let val_id decl_tipo {
                             tabela_simb[tab_idx($<str>2)].tipo = $<rhs.t>3;
                             char* t = typ2c($<rhs.t>3);

                             char* buf = alloc(20 + strlen($2));
                             sprintf(buf, "%s %s;\n", t, $2);
                             $$ = buf;
                            }
     ;
decl_tipo : /*epsilon*/  { $<rhs.t>$ = INT; }
          | ':' tipo     { $<rhs.t>$ = $<rhs.t>2; }


_tipo : /*epsilon*/  { $<rhs.t>$ = VOID; }
      |  tipo        { $<rhs.t>$ = $<rhs.t>1; }

_tipos : /*epsilon*/  { 
                           int* buf = alloc(sizeof(int));
                           ass* sig = alloc(sizeof(sig));

                           buf[0] = VOID;
                           *sig = (ass){
                               .num_args = 0,
                               .args = buf
                           };
                           $<rhs.u>$ = FUNC;
                           $<rhs.a>$ = sig;
                      }
      |  tipos        {
                           $<rhs.u>$ = $<rhs.u>1;
                           $<rhs.a>$ = $<rhs.a>1;
                      }
      ;
tipos : tipo         {
              int tipo = $<rhs.t>1;
              int* buf = alloc(sizeof(tipo));
              ass* sig = alloc(sizeof(sig));
              
              buf[0] = tipo;
              *sig = (ass){
                  .num_args = 1,
                  .args     = buf,
              };
              
              $<rhs.u>$ = FUNC;
              $<rhs.a>$ = sig;
          }
      | tipos tipo   {
              int tipo     = $<rhs.t>2;
              ass* sig     = $<rhs.a>1;
              int num_args = sig->num_args + 1;
              
              int* buf = realloc(sig->args, num_args*sizeof(tipo));
              buf[num_args-1] = tipo;

              ass* sig_o = alloc(sizeof(ass));
              *sig_o = (ass){
                  .num_args = num_args,
                  .args     = buf,
              };
              
              $<rhs.a>$ = sig_o;
              $<rhs.u>$ = FUNC;
          }
      ;
tipo  : typ_int  { $<rhs.t>$ = INT; }
      | typ_flt  { $<rhs.t>$ = FLT; }
      | typ_str  { $<rhs.t>$ = STR; }
      ;

assn : val_id assign exp  {
    char* buf = alloc(100 + strlen($1) + strlen($3));
    sprintf(buf, "%s\n"
                 "store(%d /*%s*/, r%d);\n", $3, tab_idx($<rhs.s>1), $1, $<rhs.r>3);
    $$ = buf;
}
;

exp  : exp_                { $$ = $1; }
     | '~' exp_            {
             int   r1 = $<rhs.r>2;
             char* t  = typ2reg($<rhs.t>2);
             int   ro = prox_reg();

             char* buf = alloc(40 + 6 + strlen($2));
             sprintf(buf, "%s\n"
                          "r%d.i = !r%d.%s;", $2, ro, r1, t);

             $<rhs.s>$ = buf;
             $<rhs.t>$ = INT;
             $<rhs.u>$ = EXPR;
             $<rhs.r>$ = ro;
         }
     | exp op_arit exp_   {
             int   r1 = $<rhs.r>1;
             int   t1 = $<rhs.t>1;
             char* f1 = typ2reg(t1);

             int   r2 = $<rhs.r>3;
             int   t2 = $<rhs.t>3;
             char* f2 = typ2reg(t2);

             int   ro = prox_reg();
             int   to = (t1 != INT ? t1 :
                         t2 != INT ? t2 : INT);
             char* fo = typ2reg(to);

             char* buf = alloc(60*2 + strlen($1) + strlen($2) + strlen($3));

             assert($<rhs.u>1 == EXPR);
             assert($<rhs.u>3 == EXPR);

             sprintf(buf, "%s\n"
                          "%s\n"
                          "r%d.%s = r%d.%s %s r%d.%s;",
                          $<rhs.s>1,
                          $<rhs.s>3,
                           ro, fo,  r1,f1, $2, r2,f2);

             $<rhs.s>$ = buf;
             $<rhs.t>$ = to;
             $<rhs.u>$ = EXPR;
             $<rhs.r>$ = ro;
         }
     ;
exp_ : term  {
    int ro = prox_reg();
    char* buf = alloc(65 + strlen($1));

    switch ($<rhs.u>1) {
       case ID: {
           int   id   = $<rhs.p>1;
           char* nome = tabela_simb[id].nome;
           char* t    = typ2reg(tabela_simb[id].tipo);
           sprintf(buf, "r%d.%s = load(%d /*%s*/).%s;",
                         ro, t,        id,  nome, t);
       } break;
       case LIT: {
           char* t = typ2reg($<rhs.t>1);
           sprintf(buf, "r%d.%s = %s;",
                         ro, t,   $1);
       } break;

       case EXPR: UNREACHABLE("term vem de ID ou LIT");
    }
    
    $<rhs.s>$ = buf;
    $<rhs.t>$ = $<rhs.t>1;
    $<rhs.u>$ = EXPR;
    $<rhs.r>$ = ro;
}

term : val_id    {
                  $<rhs.s>$ = $1;
                  $<rhs.t>$ = tabela_simb[tab_idx($1)].tipo;
                  $<rhs.u>$ = ID;
                  $<rhs.p>$ = tab_idx($1);
                 }
     | val_int   {
                  $<rhs.s>$ = $1;
                  $<rhs.t>$ = INT;
                  $<rhs.u>$ = LIT;
                 }
     | val_flt   {
                  $<rhs.s>$ = $1;
                  $<rhs.t>$ = FLT;
                  $<rhs.u>$ = LIT;
                 }
     | val_str   {
                  $<rhs.s>$ = $1;
                  $<rhs.t>$ = STR;
                  $<rhs.u>$ = LIT;
                 }
     ;

%%       /* C code */

int get_loc () {
    static int count = 0;
    return count++;
}
int acessa_reg (bool reset, int inc) { //quando o struct tiver melhor começar do 0 (tirar checks que assumem r=0 inválido)
    static int count = 1;
    if (reset) count = 1;

    return count += inc;
}

// buffer overflow / array out of bounds fácil (melhor ter menos que 511 variáveis...). perdão
int acessa_tab (char* nome, bool reset) {
    int i = 1;
    for (char* nome_tab; nome_tab = tabela_simb[i].nome; i++) {
        if (reset) tabela_simb[i].nome = 0, tabela_simb[i].tipo = 0;

        else if (nome != NULL) if (streql(nome, nome_tab)) return i;
    }
    if (nome != NULL) return tabela_simb[i].nome = nome, i;

    return 0;
}

// buffer overflow / array out of bounds fácil (melhor ter menos que 511...). perdão
int registra_func (char* nome, ass sig) {
    int i = 1;
    for (char* nome_tab; nome_tab = tabela_func[i].nome; i++) {
        if (nome != NULL) if (streql(nome, nome_tab)) return i;
    }
    if (nome != NULL) tabela_func[i].nome = nome, tabela_func[i].sig = sig;

    return i;
}
// array out of bounds fácil (melhor ter menos que 511...). perdão
int procura_func (char* nome) {
    int i = 1;
    for (char* nome_tab; nome_tab = tabela_func[i].nome; i++) {
        if (streql(nome, nome_tab)) return i;
    } return 0;
}

char* typ2fmt(int tipo) {
    char* ret = (tipo == INT ? "%d" :
                 tipo == FLT ? "%f" :
                 tipo == STR ? "%s" : NULL);
    assert(ret);
    return ret;
}
char* typ2reg(int tipo) {
    char* ret = (tipo == INT ? "i" :
                 tipo == FLT ? "f" :
                 tipo == STR ? "p" : NULL);
    assert(ret);
    return ret;
}
char* typ2c(int tipo) {
    char* ret = (tipo == INT  ? "int"   :
                 tipo == FLT  ? "float" :
                 tipo == STR  ? "char*" :
                 tipo == VOID ? "void"  :  NULL);
    assert(ret);
    return ret;
}

int main (int argc, char** argv) {
    if (argc > 1) yyin = fopen(argv[1], "rt");

    #ifdef DEBUG
        yydebug = 1;
    #endif

    return yyparse();
}
