%{

int yylex();

/* C declarations used in actions */
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>

static struct {char* nome; int tipo;} tabela_simb[512];
int tab_idx(char*);
int get_loc();
int get_reg();

#define yyerror(fmt, ...) fprintf(stderr, fmt "\n", ##__VA_ARGS__)

#define str2cpy(buf, s1, s2) strcat(strcpy(buf, s1), s2)
#define strdup(s)            strcpy(malloc(strlen(s)), s)

%}

/* Yacc definitions */
%union {
    char* str;
    struct {
        char* s;
        enum { INT = 0, FLT, STR } t;
        int r;
        int p;
    } rhs;
}

%start prog
%token cmd_print cmd_scan cmd_exit cmd_for cmd_if cmd_do cmd_end cmd_let
%token typ_int typ_flt typ_str assign 
%token <str> val_id val_int val_flt val_str op_arit

%type <str> prog block decls decl stmts stmt assn exp term

%%

/* descriptions of expected inputs     corresponding actions (in C) */

prog    : decls block           {
                printf("#include <stdio.h>\n"
                       "\n"
                       "#define TAM_MEM 1024\n"
                       "#include \"mem.h\"\n"
                       "\n"
                       "int main () {\n"
                           "%s\n"
                           "// %d registradores usados\n"
                           "%s\n"
                           "return 0;\n"
                           "\n"
                       "}\n",          $1, get_reg(), $2);
            }

block   : cmd_do stmts cmd_end  { $$ = $2; }

stmts   : /*epsilon*/       { $$ = ""; }
        | stmt ';' stmts    {
                char* buf = malloc(strlen($1) + strlen($3));
                $$ = strcat(strcpy(buf, $1), $3);
            }
stmt    : assn               { $$ = $1; }
        | cmd_exit           { $$ = "exit(EXIT_SUCCESS);\n"; }
        | cmd_print exp      {
                int r1;
                char* t = ($<rhs.t>2 == INT ? "%d" :
                           $<rhs.t>2 == FLT ? "%f" :
                           $<rhs.t>2 == STR ? "%s" : NULL);
                char* buf = malloc(100 + strlen($2));

                char* s = buf;
                if ($<rhs.p>2) { // se é id
                     r1 = get_reg();
                     s += sprintf(s, "r%d = load(%s);\n", r1, tabela_simb[$<rhs.p>2].nome);
                 } else { // se é uma exp normal
                     r1 = $<rhs.r>2;
                     s += sprintf(s, "%s\n", $2);
                     s += sprintf(s, "r%d = %s;\n", r1, $2);
                }
                s += sprintf(s, "printf(\"%s\\n\", r%d);\n", t, r1);
                $$ = buf;
            }
        | cmd_scan val_id    {
                int tipo = tabela_simb[tab_idx($2)].tipo;
                char* t = (tipo == INT ? "%d" :
                           tipo == FLT ? "%f" :
                           tipo == STR ? "%s" : NULL);

                char* buf = malloc(20 + strlen($2));
                sprintf(buf, "scanf(\"%s\", &%s);\n", t, $2);
                $$ = buf;
            }
        | cmd_if exp block   {
                int loc = get_loc();
                char* buf = malloc(10*4 + strlen($2) + strlen($3));

                char* s = buf;
                s += sprintf(s, "if (!%s) goto out%d;\n", $2, loc);
                s += sprintf(s, "    %s", $3);
                s += sprintf(s, "out%d:\n", loc);

                $$ = buf;
            }
        | cmd_for exp block  {
                int loc = get_loc();
                char* buf = malloc(10*5 + strlen($2) + strlen($3));

                char* s = buf;
                s += sprintf(s, "loop%d:\n", loc);
                s += sprintf(s, "if (!%s) goto out%d;\n", $2, loc);
                s += sprintf(s, "    %s", $3);
                s += sprintf(s, "goto loop%d;\n", loc);
                s += sprintf(s, "out%d:\n", loc);

                $$ = buf;
            }
        | ';'                {;}
        ;

decls : /*epsilon*/     { $$ = ""; }
      | decl ';' decls  {
                         char* buf = malloc(strlen($1) + strlen($3));
                         $$ = str2cpy(buf, $1, $3);
                        }
      ;
decl : cmd_let val_id tipo {
                            tabela_simb[tab_idx($<str>2)].tipo = $<rhs.t>3;
                            char* t = ($<rhs.t>3 == INT ? "int"   :
                                       $<rhs.t>3 == FLT ? "float" :
                                       $<rhs.t>3 == STR ? "char*" : NULL);

                            char* buf = malloc(8 + strlen($2));
                            sprintf(buf, "%s %s;\n", t, $2);
                            $$ = buf;
                           }
     ;
tipo : /*epsilon*/  { $<rhs.t>$ = INT; }
     | ':' typ_int  { $<rhs.t>$ = INT; }
     | ':' typ_flt  { $<rhs.t>$ = FLT; }
     | ':' typ_str  { $<rhs.t>$ = STR; }
     ;

assn : val_id assign exp  {
                           char* buf = malloc(100 + strlen($1) + strlen($3));
                           sprintf(buf, "%s\n"
                                        "store(%s, r%d);\n", $3, $1, $<rhs.r>3);
                           $$ = buf;
                          }
     ;

exp  : term               {
             $$ = $1;
             //int r1;
         }
     | '~' term           {
             int rid, ro = get_reg();
             char* buf = malloc(40 + 3 + strlen($2));

             char* s = buf;
             if ($<rhs.p>2) { // se é id
                 rid = get_reg();
                 s += sprintf(s, "r%d = load(%s);\n", rid, tabela_simb[$<rhs.p>2].nome);
             }
             s += sprintf(s, "r%d = !%s;", ro, $2);

             $<rhs.s>$ = buf;
             $<rhs.t>$ = $<rhs.t>2;
             $<rhs.r>$ = ro;
         }
     //| '~' exp            {
     //        int ro = get_reg();
     //        char* buf = malloc(12 + 3 + strlen($2));
     //        sprintf(buf, "%s;\n"
     //                     "r%d = !%d;", $2, ro, $<rhs.r>2);
     //        $<rhs.s>$ = buf;
     //        $<rhs.t>$ = $<rhs.t>2;
     //        $<rhs.r>$ = ro;
     //    }
     | exp op_arit term   {
             int r1, r2;
             char* buf = malloc(60*3 + strlen($1) + strlen($2) + strlen($3));

             char* s = buf;
             if ($<rhs.p>1) { // se é id
                 r1 = get_reg();
                 s += sprintf(s, "r%d = load(%s);\n", r1, tabela_simb[$<rhs.p>1].nome);
             } else if ($<rhs.r>1) { //se é exp
                 r1 = $<rhs.r>1;
                 s += sprintf(s, "%s;\n", $1);
             } else {
                 r1 = get_reg();
                 s += sprintf(s, "r%d = %s;\n", r1, $1);
             }
             if ($<rhs.p>3) { // se é id
                 r2 = get_reg();
                 s += sprintf(s, "r%d = load(%s);\n", r2, tabela_simb[$<rhs.p>3].nome);
             } else { // se é um literal
                 r2 = get_reg();
                 s += sprintf(s, "r%d = %s;\n", r2, $3);
            }
             int ro = get_reg();
             s += sprintf(s, "r%d = r%d %s r%d;", ro, r1, $2, r2);

             $<rhs.s>$ = buf;
             $<rhs.t>$ = !!($<rhs.t>1 + $<rhs.t>3); //isso retorna FLT se um dos lados não é INT.... desculpa....
             $<rhs.r>$ = ro;
             $<rhs.p>$ = 0;
         }
     ;

term : val_id    { 
                  $<rhs.s>$ = $1;
                  $<rhs.t>$ = tabela_simb[tab_idx($1)].tipo;
                  $<rhs.p>$ = tab_idx($1);
                  $<rhs.r>$ = 0;
                 }
     | val_int   {
                  $<rhs.s>$ = $1;
                  $<rhs.t>$ = INT;
                  $<rhs.r>$ = 0;
                  $<rhs.p>$ = 0;
                 }
     | val_flt   {
                  $<rhs.s>$ = $1;
                  $<rhs.t>$ = FLT;
                  $<rhs.r>$ = 0;
                  $<rhs.p>$ = 0;
                 }
     | val_str   {
                  $<rhs.s>$ = $1;
                  $<rhs.t>$ = STR;
                  $<rhs.r>$ = 0;
                  $<rhs.p>$ = 0;
                 }
     ;

%%       /* C code */

int get_loc () {
    static int count = 0;
    return count++;
}
int get_reg () {
    static int count = 1;
    return count++;
}
int tab_idx (char* nome) { // buffer overflow / array out of bounds fácil (melhor ter menos que 511 variáveis...). perdão
    int i = 1;
    for (char* nome_tab; nome_tab = tabela_simb[i].nome; i++) {
        if (strcmp(nome, nome_tab) == 0) return i;
    }
    tabela_simb[i].nome = nome; 
    return i;
}

int main (void) {
    return yyparse();
}
