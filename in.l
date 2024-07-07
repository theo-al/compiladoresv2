%{
#include "y.tab.h"

int yylex();

#define yyerror(fmt, ...) fprintf(stderr, fmt "\n", ##__VA_ARGS__)

%}

%%
"#".*\n           {;}
[ \t\n]           {;}

"print"           { return cmd_print; }
"imprime"         { return cmd_print; }

"devolve"         { return cmd_return; }

"scan"            { return cmd_scan; }
"le"              { return cmd_scan; }

"exit"            { return cmd_exit; }
"sai"             { return cmd_exit; }

"para"            { return cmd_for; }
"si"              { return cmd_if; }
"fa"              { return cmd_do; }
"ha"              { return cmd_let; }
"fi"              { return cmd_end; }

":="              { return assign; }
"int"             { return typ_int; }
"flt"             { return typ_flt; }
"str"             { return typ_str; }

\"(\\.|[^"\\])*\" {
                   yylval.str = strdup(yytext);
                   return val_str;
                  }
[a-zA-Z]+         {
                   yylval.str = strdup(yytext);
                   return val_id;
                  }
[0-9]+"."[0-9]+   {
                   yylval.str = strdup(yytext);
                   return val_flt;
                  }
[0-9]+            {
                   yylval.str = strdup(yytext);
                   return val_int;
                  }
[-+*/]            {
                   yylval.str = strdup(yytext);
                   return op_arit;
                  }
[~|><=\^:;]       { return yytext[0]; }

.                 { yyerror("unexpected character: %c", yytext[0]); }

%%
int yywrap (void) {return 1;}