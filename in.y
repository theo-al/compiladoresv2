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

#define yyerror(fmt, ...) fprintf(stderr, fmt "\n", ##__VA_ARGS__)

#define str2cpy(buf, s1, s2) strcat(strcpy(buf, s1), s2)
#define strdup(s)            strcpy(malloc(strlen(s)), s)

%}

/* Yacc definitions */
%union {
    char* str;
    struct {
        char* s;
        enum {INT = 0, FLT, STR} t;
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
                       //"\n"
                       //"typedef union {int i; float f; void* s;} reg;\n"
                       "\n"
                       "int main () {\n"
                           "%s\n"
                           "%s\n"
                           "return 0;\n"
                           "\n"
                       "}\n",          $1, $2);
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
                char* t = ($<rhs.t>2 == INT ? "%d" :
                           $<rhs.t>2 == FLT ? "%f" :
                           $<rhs.t>2 == STR ? "%s" : NULL);

                char* buf = malloc(20 + strlen($2));
                sprintf(buf, "printf(\"%s\\n\", %s);\n", t, $2);
                $$ = buf;
            }
        | cmd_scan val_id    {
                int tipo = tabela_simb[tab_idx($2)].tipo;
                char* t = (tipo == INT ? "%d" :
                           tipo == FLT ? "%f" :
                           tipo == STR ? "%s" : NULL);

                char* buf = malloc(20 + strlen($2));
                sprintf(buf, "scanf(\"%s\", &%s;\n", t, $2);
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
                           char* buf = malloc(6 + strlen($1) + strlen($3));
                           sprintf(buf, "%s = %s;\n", $1, $3);

                           $$ = buf;
                          }
     ;

exp  : term               { $$ = $1; }
     | '~' term           {
             char* buf = malloc(2 + strlen($2));
             $<rhs.s>$ = str2cpy(buf, "!", $2);
             $<rhs.t>$ = $<rhs.t>2;
         }
     | exp op_arit term   {
             char* buf = malloc(5 + strlen($1) + strlen($2) + strlen($3));
             sprintf(buf, "(%s %s %s)", $1, $2, $3);
             $<rhs.s>$ = buf;
             $<rhs.t>$ = !!($<rhs.t>1 + $<rhs.t>3); //isso retorna FLT se um dos lados não é INT.... desculpa....
         }
     ;

term : val_id    { 
                  $<rhs.s>$ = $1;
                  $<rhs.t>$ = tabela_simb[tab_idx($1)].tipo;
                 }
     | val_int   {
                  $<rhs.s>$ = $1;
                  $<rhs.t>$ = INT;
                 }
     | val_flt   {
                  $<rhs.s>$ = $1;
                  $<rhs.t>$ = FLT;
                 }
     | val_str   {
                  $<rhs.s>$ = $1;
                  $<rhs.t>$ = STR;
                 }
     ;

%%       /* C code */

int get_loc () {
    static int count = 0;
    return count++;
}
int tab_idx (char* nome) { // buffer overflow / array out of bounds fácil (melhor ter menos que 512 variáveis...). perdão
    int i = 0;
    for (char* nome_tab; nome_tab = tabela_simb[i].nome; i++) {
        if (strcmp(nome, nome_tab) == 0) return i;
    }
    tabela_simb[i].nome = nome; 
    return i;
}

int main (void) {
    return yyparse();
}
