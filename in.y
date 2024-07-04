%{

int yylex();

/* C declarations used in actions */
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <assert.h>

static struct {char* nome; int tipo;} tabela_simb[512];

int acessa_tab(char*, bool);
#define tab_idx(nome) acessa_tab(nome, false)
#define reset_tab()   acessa_tab("", true)

int acessa_reg(bool);
#define get_reg()     acessa_reg(false)
#define reset_reg()   acessa_reg(true)

int get_loc();

char* typ2fmt(int tipo);
char* typ2reg(int tipo);
char* typ2c(int tipo);

#define yyerror(fmt, ...) fprintf(stderr, fmt "\n", ##__VA_ARGS__)
#define UNREACHABLE(...)  assert(0);


#define alloc(sz)            calloc(1, 100 + sz)
#define str2cpy(buf, s1, s2) strcat(strcpy(buf, s1), s2)
#define strdup(s)            strcpy(alloc(strlen(s)), s)

typedef struct {
    int ret;
    int num_args;
    int* args;
} ass;

%}

/* Yacc definitions */
%union {
    char* str;
    struct {
        char* s;
        enum { VOID = 0, INT, FLT, STR } t;
        enum { ID, LIT, EXPR, FUNC } u;
        union {
            int r;
            int p;
            void* a;
        };
    } rhs;
}

%start prog
%token cmd_print cmd_scan cmd_exit cmd_for cmd_if cmd_do cmd_end cmd_let
%token typ_int typ_flt typ_str assign 
%token <str> val_id val_int val_flt val_str op_arit

%type <str> prog func block decls decl stmts stmt assn exp exp_ term 
%type <rhs> assinatura

%%

/* descriptions of expected inputs     corresponding actions (in C) */

prog : func  {
    printf("%s", $1);
}

func : decls assinatura block  {
    assert(strcmp($<rhs.s>2, "ini") == 0);
    ass* sig = $<rhs.a>2;
    int num_reg = get_reg();
    char* buf = alloc(100 + num_reg*30 + sig->num_args*10 + strlen($3));
    
    char* s = buf;
    s += sprintf(s, "#include <stdio.h>\n"
                    "#include <stdlib.h>\n"
                    "\n"
                    "#define TAM_MEM 1024\n"
                    "#include \"mem.h\"\n"
                    "\n");

    s += sprintf(s, "int main () {\n"
                    "%s\n", $1);
    {
        s += sprintf(s, "reg ");
        for (int i = 1; i < num_reg; i++) {
            s += sprintf(s, "r%d, ", i);
        } s += sprintf(s, "r%d;\n", num_reg);
    }
    s += sprintf(s, "\n"
                    "%s"
                    "return 0;\n"
                    "}\n",     $<rhs.s>3);

    reset_reg();

    $<rhs.s>$ = buf;
    $<rhs.u>$ = FUNC;
    $<rhs.a>$ = sig;
}
;

assinatura : _tipo val_id _tipos {
                    ass* sig = $<rhs.a>3;
                    sig->ret = $<rhs.t>1,
                    
                    $<rhs.s>$ = $2;
                    $<rhs.u>$ = FUNC;
                    $<rhs.a>$ = sig;
               }
           ;


block   : cmd_do stmts cmd_end  { $$ = $2; }
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
                char* tc   = typ2c(tipo);

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
        | cmd_if exp block   {
                int loc = get_loc();
                char* buf = alloc(10*4 + strlen($2) + strlen($3));
                int   r1 = $<rhs.r>2;
                char* t1 = typ2reg($<rhs.t>2);

                char* s = buf;
                s += sprintf(s, "%s\n", $2);
                s += sprintf(s, "if (!r%d.%s) goto out%d;\n", r1, t1, loc);
                s += sprintf(s, "%s\n", $3);
                s += sprintf(s, "out%d:\n", loc);
                //s += sprintf(s, "\n");

                $$ = buf;
            }
        | cmd_for exp block  {
                int loc = get_loc();
                char* buf = alloc(10*5 + strlen($2) + strlen($3));
                int   r1 = $<rhs.r>2;
                char* t1 = typ2reg($<rhs.t>2);

                char* s = buf;
                s += sprintf(s, "loop%d:\n", loc);
                s += sprintf(s, "%s\n", $2);
                s += sprintf(s, "if (!r%d.%s) goto out%d;\n", r1, t1, loc);
                s += sprintf(s, "%s", $3);
                s += sprintf(s, "goto loop%d;\n", loc);
                s += sprintf(s, "out%d:\n", loc);
                //s += sprintf(s, "\n");

                $$ = buf;
            }
        | ';'                {;}
        ;

decls : /*epsilon*/     { $$ = ""; }
      | decl ';' decls  {
                         char* buf = alloc(strlen($1) + strlen($3));
                         $$ = str2cpy(buf, $1, $3);
                        }
      ;
decl : cmd_let val_id tipo_ {
                            tabela_simb[tab_idx($<str>2)].tipo = $<rhs.t>3;
                            char* t = typ2c($<rhs.t>3);

                            char* buf = alloc(20 + strlen($2));
                            sprintf(buf, "//%s %s;\n", t, $2);
                            $$ = buf;
                           }
     ;

_tipo : /*epsilon*/  { $<rhs.t>$ = VOID; }
      |  tipo        { $<rhs.t>$ = $<rhs.t>1; }

tipo_ : /*epsilon*/  { $<rhs.t>$ = INT; }
      | ':' tipo     { $<rhs.t>$ = $<rhs.t>2; }
      ;
_tipos : /*epsilon*/  { 
                           int* buf = alloc(sizeof(int));
                           buf[0] = VOID;
                           $<rhs.u>$ = FUNC;
                           $<rhs.a>$ = buf;
                      }
      |  tipos        {
                           $<rhs.u>$ = $<rhs.u>1;
                           $<rhs.a>$ = $<rhs.a>1;
                      }
      ;
tipos : tipo         {
              int tipo = $<rhs.t>1;
              int* buf = alloc(sizeof(tipo));
              buf[0] = tipo;
              ass* sig;
              *sig = (ass){
                  .num_args = 1,
                  .args     = buf,
              };
              
              $<rhs.a>$ = sig;
              $<rhs.u>$ = FUNC;
          }
      | tipos tipo   {
              int tipo     = $<rhs.t>2;
              ass* sig     = $<rhs.a>1;
              int num_args = sig->num_args + 1;
              
              int* buf = realloc(sig->args, num_args*sizeof(tipo));
              buf[num_args-1] = tipo;

              ass* sig_o;
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
             int   ro = get_reg();
             
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

             int   ro = get_reg();
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
    int ro = get_reg();
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
int acessa_reg (bool reset) {
    static int count = 1;
    if (reset) count = 0;

    return count++;
}
int acessa_tab (char* nome, bool reset) { // buffer overflow / array out of bounds fácil (melhor ter menos que 511 variáveis...). perdão
    int i = 1;
    for (char* nome_tab; nome_tab = tabela_simb[i].nome; i++) {
        if (reset) tabela_simb[i].nome = 0, tabela_simb[i].tipo = 0;

        if (strcmp(nome, nome_tab) == 0) return i;
    }
    tabela_simb[i].nome = nome; 
    return i;
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
    char* ret = (tipo == INT ? "int"   :
                 tipo == FLT ? "float" :
                 tipo == STR ? "char*" : NULL);
    assert(ret);
    return ret;
}

int main (void) {
    return yyparse();
}
