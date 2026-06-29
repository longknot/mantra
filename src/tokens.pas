unit tokens;

{$I mantra.inc}

interface

const
  // NEW NODE CATEGORIES:
  TK_TYPE          = $000000C0;
  TK_IDENTIFIER    = $00000040;
  TK_SPECIAL       = $00000080;  // e.g. separator, repeat, rule, transformation, ...
  TK_SCOPE         = $000000C0;  // (), {}, [], ...

  TK_ID_MASK       = $0000003F;
  TK_TYPE_MASK     = $000000FF;

  TK_EXTRA         = $00000100;  // 255 arbitrary values -> combined with ID field
  TK_EXTRA_MASK    = $0000FF00;
  TK_SELECTOR_MASK = TK_EXTRA * $C0;  // 2 bits in TK_EXTRA range (lhs/rhs/all)
  TK_SELECTOR_LHS  = TK_EXTRA * $40;
  TK_SELECTOR_RHS  = TK_EXTRA * $80;
  TK_SELECTOR_ALL  = TK_EXTRA * $C0;
  TK_SELECTOR_OP   = TK_EXTRA * $20;
  TK_SELECTOR_EXTRA_MASK = TK_SELECTOR_MASK or TK_SELECTOR_OP;

  TK_IMAG_I        = TK_EXTRA * $01;  // imaginary unit (i)
  TK_IMAG_J        = TK_EXTRA * $02;  // imaginary unit (j)
  TK_IMAG_K        = TK_EXTRA * $03;  // imaginary unit (k)

  TK_RAND          = TK_EXTRA * $06;
  TK_SQR           = TK_EXTRA * $07;
  TK_SQRT          = TK_EXTRA * $08;
  TK_SIN           = TK_EXTRA * $09;
  TK_COS           = TK_EXTRA * $0A;
  TK_TAN           = TK_EXTRA * $0B;
  TK_EXP           = TK_EXTRA * $0C;
  TK_LN            = TK_EXTRA * $0D;
  TK_LOG2          = TK_EXTRA * $0E;
  TK_LOG10         = TK_EXTRA * $0F;
  TK_MIN           = TK_EXTRA * $10;
  TK_MAX           = TK_EXTRA * $11;
  TK_LOGN          = TK_EXTRA * $12;
  TK_ATAN2         = TK_EXTRA * $13;
  TK_HYPOT         = TK_EXTRA * $14;
  TK_POWER         = TK_EXTRA * $15;
  TK_ABS           = TK_EXTRA * $16;
  TK_SIGN          = TK_EXTRA * $17;
  TK_FLOOR         = TK_EXTRA * $18;
  TK_CEIL          = TK_EXTRA * $19;
  TK_ROUND         = TK_EXTRA * $1A;
  TK_MOD           = TK_EXTRA * $1B;
  TK_ARG           = TK_EXTRA * $1C;
  TK_CONJ          = TK_EXTRA * $1D;
  TK_IMAG          = TK_EXTRA * $1E;
  TK_REAL          = TK_EXTRA * $1F;

  // compute should be able to reduce e.g. + 1k 1i 1j 1 1k 1 to + 2 1i 1j 2k.
  // N: implement e.g. COMPLEX_ADD() , COMPLEX_MUL() in compute pipeline.

  //TK_IGNORE        = $80000000;

  // Operator bits:
  // [ 3 bit = $C0 ] : comparison / boolean operator
  // [ 1 bit = $30 ] : imaginary / complex operator
  // [ 4 bit = $0F ] : arithmetic operator ( + - * / )
  TK_OPERATOR      = $00010000;  // 255 operators
  TK_OPERATOR_MASK = $00FF0000;

  TK_RELATIONAL_MASK = $00F00000;  // 3 bits for comparison / boolean operators
  TK_RELATIONAL_GE   = $00200000;  // 0 0 1 : >=
  TK_RELATIONAL_LE   = $00400000;  // 0 1 0 : <=
  TK_RELATIONAL_EQ   = $00600000;  // 0 1 1 : == (<= or >=)
  TK_RELATIONAL_NOT  = $00800000;  // 1 0 0 : !
  TK_RELATIONAL_LT   = $00A00000;  // 1 0 1 : <  (not >=)
  TK_RELATIONAL_GT   = $00C00000;  // 1 1 0 : >  (not <=)
  TK_RELATIONAL_NEQ  = $00E00000;  // 1 1 1 : != (not ==)

  // boolean operators
  TK_BOOLEAN_MASK    = $00F00000;
  TK_BOOLEAN_OP      = $00100000;
  TK_BOOLEAN_AND     = $00300000;  // 0 0 1 : and
  TK_BOOLEAN_OR      = $00500000;  // 0 1 0 : or
  TK_BOOLEAN_XOR     = $00700000;  // 0 1 1 : xor
  TK_BOOLEAN_NOT     = $00800000;  // 1 0 0 : not
  TK_BOOLEAN_NAND    = $00B00000;  // 1 0 1 : nand
  TK_BOOLEAN_NOR     = $00D00000;  // 1 1 0 : nor
  TK_BOOLEAN_NXOR    = $00F00000;  // 1 1 1 : nxor


  // TK_OP_COMPLEX_MASK    = $00030000;  // 2 bits for imaginary / complex operators
  // TK_OP_IMAGINARY       = $00010000;

  // TK_OP_ARITHMETIC_MASK = $000F00000;

  TK_META          = $01000000;
  TK_META_MASK     = $FF000000;
  // "meta" operators
  //'{ (1 2 3 4 5 6) | x . y z =>  ( x y z ) ... | w => w ... }';
  TK_DOT           = TK_META * $01;   // used by matching rules
  TK_TILDE         = TK_META * $02;   // ~ = compute flag
  TK_FIXED         = TK_META * $04;   // \ = fixed flag (do not transform)
  TK_UNFIX         = TK_META * $08;
  TK_DOLLAR        = TK_META * $10;
  TK_AT            = TK_META * $20;
  TK_CARET         = TK_META * $40;
  TK_ALLCAPS       = TK_META * $80;

  // WHITESPACE & SEPARATORS
  //TK_COMMA              = TK_SEPARATOR * 1;
  //TK_SEPARATOR          = $00000100;

  // IgnoreMask := TK_WHITESPACE or TK_NEWLINE or TK_LINECOMMENT or TK_BLOCKCOMMENT;
  //TK_WHITESPACE         = TK_IGNORE;
  TK_SPACE              = 1;
  TK_TAB                = 2;
  TK_LINECOMMENT        = 3;
  TK_BLOCKCOMMENT       = 4;
  TK_NEWLINE            = 5;
  TK_CR                 = 6;

  TK_PATTERN_KEY        = 16;
  TK_PATTERN_INDEX      = 17;

  // STATEMENT
  TK_SEMICOLON          = 8;

  // IDENTIFIERS ($01)
  TK_UNKNOWN            = 0;

  TK_VARIABLE           = TK_IDENTIFIER + 1;
  TK_CONSTANT           = TK_IDENTIFIER + 2;   // 'const'
  TK_STRING             = TK_IDENTIFIER + 3;
  TK_INTEGER            = TK_IDENTIFIER + 4;
  TK_FLOAT              = TK_IDENTIFIER + 6;
  TK_COMPLEX            = TK_IDENTIFIER + 7;

  TK_RULE               = TK_IDENTIFIER + 8;   // 'rule'
  TK_FUNCTION           = TK_IDENTIFIER + 9;   // 'function'
  TK_NAMESPACE          = TK_IDENTIFIER + 10;  // 'namespace'
  TK_OBJECT             = TK_IDENTIFIER + 11;  // 'object'
  TK_SELECTOR           = TK_IDENTIFIER + 12;  // 'selector'
  TK_EXEC               = TK_IDENTIFIER + 13;  // 'exec'
  TK_DEFINE             = TK_IDENTIFIER + 14;
  TK_NATIVE_FUNCTION    = TK_IDENTIFIER + 15;
  TK_PACKAGE            = TK_IDENTIFIER + 16;
  TK_IMPORT             = TK_IDENTIFIER + 17;
  TK_INCLUDE            = TK_IDENTIFIER + 18;
  TK_PRINT              = TK_IDENTIFIER + 19;

  TK_EXPLODE            = TK_IDENTIFIER + 20;
  TK_IMPLODE            = TK_IDENTIFIER + 21;
  TK_TREE               = TK_IDENTIFIER + 22;
  TK_CALLABLE           = TK_IDENTIFIER + 23;
  TK_IR                 = TK_IDENTIFIER + 24;

  TK_PATTERN            = TK_IDENTIFIER + 25;
  TK_PAIR_VALUE         = TK_IDENTIFIER + 26;
  TK_QUERY_KEYS         = TK_IDENTIFIER + 27;
  TK_QUERY_VALUES       = TK_IDENTIFIER + 28;
  TK_NULL               = TK_IDENTIFIER + 29;
  TK_JSON_LOAD          = TK_IDENTIFIER + 30;
  TK_SYSTEM             = TK_IDENTIFIER + 31;
  TK_ASSIGN_PATH        = TK_IDENTIFIER + 32;
  TK_QUERY_CHILDREN     = TK_IDENTIFIER + 33;
  TK_GET                = TK_IDENTIFIER + 34;
  TK_YAML_LOAD          = TK_IDENTIFIER + 35;
  TK_PATH_SEGMENT       = TK_IDENTIFIER + 36;
  TK_MAKE_PAIR          = TK_IDENTIFIER + 37;
  TK_FMT                = TK_IDENTIFIER + 38;
  TK_PRINTF             = TK_IDENTIFIER + 39;
  TK_RENDER             = TK_IDENTIFIER + 40;
  TK_GLOBAL             = TK_IDENTIFIER + 41;
  TK_ALIAS              = TK_IDENTIFIER + 42;
  TK_SCOPE_FRAME        = TK_IDENTIFIER + 43;
  TK_RULE_FORWARD       = TK_IDENTIFIER + 44;
  TK_RULE_REVERSE       = TK_IDENTIFIER + 45;
  TK_JSON_ENCODE        = TK_IDENTIFIER + 46;
  TK_BOOLEAN            = TK_IDENTIFIER + 47;
  TK_JSON_EMPTY_OBJECT  = TK_IDENTIFIER + 48;
  TK_JSON_EMPTY_ARRAY   = TK_IDENTIFIER + 49;
  TK_DISPLAY            = TK_IDENTIFIER + 50;
  TK_JSON_SAVE          = TK_IDENTIFIER + 51;


  // N: AddTransition(TK_INTEGER, TK_IMAG_I), AddTransition(TK_FLOAT, TK_IMAG_I)
  TK_IMAG_I_INT    = TK_IMAG_I or TK_INTEGER;  // imaginary unit (i)
  TK_IMAG_J_INT    = TK_IMAG_J or TK_INTEGER;  // imaginary unit (j)
  TK_IMAG_K_INT    = TK_IMAG_K or TK_INTEGER;  // imaginary unit (k)
  TK_IMAG_I_FLOAT  = TK_IMAG_I or TK_FLOAT;    // imaginary unit (i)
  TK_IMAG_J_FLOAT  = TK_IMAG_J or TK_FLOAT;    // imaginary unit (j)
  TK_IMAG_K_FLOAT  = TK_IMAG_K or TK_FLOAT;    // imaginary unit (k)


  // SPECIAL ($02)
  TK_DOUBLEDOT          = TK_SPECIAL + 1;
  TK_TRIPLEDOT          = TK_SPECIAL + 2;
  TK_COLON              = TK_SPECIAL + 3;
  TK_COMMA              = TK_SPECIAL + 4;

  // TK_UNDERSCORE         = TK_OPERATOR * 7;
  TK_PIPE               = TK_SPECIAL + 5;
  TK_HASH               = TK_SPECIAL + 6;

  TK_ASSIGNMENT         = TK_SPECIAL + 7;
  TK_DEEP_ASSIGN        = TK_SPECIAL + 30; // :=
  TK_DEEP_ASSIGN_OVERWRITE = TK_SPECIAL + 31; // >:=
  TK_DEEP_ASSIGN_KEEP   = TK_SPECIAL + 32; // <:=
  TK_DEEP_ASSIGN_FAIL   = TK_SPECIAL + 33; // !:=

  TK_QUESTIONMARK       = TK_SPECIAL + 8;
  TK_IMPLIES            = TK_SPECIAL + 12;


  TK_RIGHT_ARROW        = TK_SPECIAL + 18;
  TK_LEFT_ARROW         = TK_SPECIAL + 19;

  TK_FORWARD            = TK_SPECIAL + 19;
  TK_MATCH_ANY_LONG     = TK_SPECIAL + 20;
  TK_MATCH_ANY          = TK_SPECIAL + 21;

  TK_BACKSLASH          = TK_SPECIAL + 22;  // outer product = tensor product
  TK_AMPERSAND          = TK_SPECIAL + 23;  // element-wise product = hadamard product
  TK_ITERATOR           = TK_SPECIAL + 24;  // staged repeat (::)

  TK_INLINE             = TK_SPECIAL + 26;

  TK_INFERENCE          = TK_SPECIAL + 27;  // e.g. 'x' in 'x => x + 1' can be inferred from context
  TK_INFERENCE_WITNESS  = TK_SPECIAL + 29;  // witness-producing inference (?|=)
  TK_VARIABLE_SUBTREE_ARROW = TK_SPECIAL + 34; // ->

  TK_SELECTION          = TK_QUESTIONMARK;
  TK_TRANSFORM          = TK_IMPLIES;        // 8   ( => )
  TK_FALLBACK           = TK_SELECTION + 3;  // 11  ( ?? )
  TK_INLINE_TRANSFORM   = TK_TRANSFORM + 1;  // 13  ( =>> )

  TK_SUBST_TRANSFORM    = TK_TRANSFORM + 2;  // 14  ( ==> )
  TK_SYMBOL_SUBST_TRANSFORM = TK_TRANSFORM + 3;  // 15  ( ==>> )
  TK_EQUIVALENCE        = TK_TRANSFORM + 4;  // 16  ( <=> )
  TK_SUBST_EQUIVALENCE  = TK_TRANSFORM + 5;  // 17  ( <==> )


  // scopes ($08)
  TK_SCOPE_BEGIN        = TK_SCOPE + 1;
  TK_SCOPE_END          = TK_SCOPE + 2;
  TK_SCOPE_BEGIN_END    = TK_SCOPE + 3;
  TK_PARENTHESIS_BEGIN  = TK_SCOPE_BEGIN;
  TK_PARENTHESIS_END    = TK_SCOPE_END;
  TK_BRACKET_BEGIN      = TK_SCOPE_BEGIN + 4;  // 5
  TK_BRACKET_END        = TK_SCOPE_END   + 4;  // 6
  TK_CURLY_BEGIN        = TK_SCOPE_BEGIN + 8;  // 9
  TK_CURLY_END          = TK_SCOPE_END   + 8;  // 10
  TK_GROUP_BEGIN        = TK_SCOPE_BEGIN + 12; // 13
  TK_GROUP_END          = TK_SCOPE_END   + 12; // 14

  // same character for BEGIN / END of scope
  // N: strings handled by tokenizer
  TK_APOSTROPHE         = TK_SCOPE_BEGIN_END;      // 3
  TK_BACKTICK           = TK_SCOPE_BEGIN_END + 4;  // 7

  // separators and whitespace
  //TK_COMMA              = TK_SEPARATOR * 1;
  //TK_SEMICOLON          = TK_SEPARATOR * 1;
  //TK_NEWLINE            = TK_SEPARATOR * 2;

  // whitespace
  //TK_SPACE              = TK_WHITESPACE + 1;
  //TK_LINECOMMENT        = TK_WHITESPACE + 2;
  //TK_BLOCKCOMMENT       = TK_WHITESPACE + 3;

  // variable index ?
  // constant index ?

  // FLAG_VALUE      = 1;
  // FLAG_FUNCTION   = 2;
  // FLAG_SUBTREE    = 4;       // ( ... )
  // FLAG_PATTERN    = 8;       // [ ... ]
  // FLAG_INDEX      = 16;      // { ... }   x{ ... } = index, [ ... ]{ ... } = count?
  // FLAG_RECURSE    = 32;
  // FLAG_HEAD       = 64;
  // FLAG_COMPUTABLE = 128;


  // 31 .. 24 23 .. 16 15 .. 08 07 .. 00
  // [ meta ] [      ] [  op  ] [  id  ]

  // TK_IDENTIFIER      = $00000001;
  // TK_SCOPE           = $00000002;
  // TK_SPECIAL         = $00000004;
  // TK_TRANSFORM       = $00000008;
  // TK_SYMBOL_MASK     = $000000F0;
  // TK_IDENTIFIER_MASK = TK_IDENTIFIER or TK_SYMBOL_MASK;
  // TK_SCOPE_MASK      = TK_SCOPE      or TK_SYMBOL_MASK;
  // TK_SPECIAL_MASK    = TK_SPECIAL    or TK_SYMBOL_MASK;
  // TK_TRANSFORM_MASK  = TK_TRANSFORM  or TK_SYMBOL_MASK;
  // TK_OPERATOR        = $00000100;
  // TK_OPERATOR_MASK   = $0000FF00;
  // TK_META_MASK       = $FF000000;


  // TK_SYMBOL_MASK     = $000000F0;
  // TK_IDENTIFIER_MASK = TK_IDENTIFIER or TK_SYMBOL_MASK;
  // TK_SCOPE_MASK      = TK_SCOPE      or TK_SYMBOL_MASK;
  // TK_SPECIAL_MASK    = TK_SPECIAL    or TK_SYMBOL_MASK;
  // TK_TRANSFORM_MASK  = TK_TRANSFORM  or TK_SYMBOL_MASK;
  TK_IDENTIFIER_MASK = TK_IDENTIFIER;
  TK_SCOPE_MASK      = TK_SCOPE;
  TK_SPECIAL_MASK    = $FF;
  TK_TRANSFORM_MASK  = TK_TRANSFORM;

  TK_ERROR              = -1;


  // operators
  TK_BINARY             = TK_OPERATOR * $80;

  TK_PLUS               = TK_OPERATOR * $01;
  TK_MINUS              = TK_OPERATOR * $02;
  TK_ASTERISK           = TK_OPERATOR * $04;  // multiplication
  TK_SLASH              = TK_OPERATOR * $08;  // reciprocal
  TK_MULTIPLY           = TK_ASTERISK;
  TK_DIVIDE             = TK_SLASH;

  // TK_PERCENTAGE         = TK_OPERATOR * $08 or TK_BINARY;  // modulus

  // TK_DIFF               = TK_OPERATOR * $0A;
  // TK_FRAC               = TK_OPERATOR * $0B;
  // TK_PROD               = TK_OPERATOR * $0C;

  TK_EXCLAMATIONMARK    = TK_OPERATOR * $0E;
  TK_DOUBLEFACTORIAL    = TK_OPERATOR * $0D;

  // relational + boolean
  // TK_EQUALS             = TK_OPERATOR * $10 or TK_BINARY;
  // TK_GREATER            = TK_OPERATOR * $11 or TK_BINARY;
  // TK_GREATER_OR_EQUAL   = TK_OPERATOR * $12 or TK_BINARY;
  // TK_LESS               = TK_OPERATOR * $13 or TK_BINARY;
  // TK_LESS_OR_EQUAL      = TK_OPERATOR * $14 or TK_BINARY;
  // TK_NOT_EQUAL          = TK_OPERATOR * $15 or TK_BINARY;

  // TK_AND                = TK_OPERATOR * $16 or TK_BINARY;
  // TK_OR                 = TK_OPERATOR * $17 or TK_BINARY;
  // TK_XOR                = TK_OPERATOR * $18 or TK_BINARY;
  // TK_NOT                = TK_OPERATOR * $19;

  //TK_NEXT              = TK_OPERATOR * $20;
  //TK_PREV              = TK_OPERATOR * $21;
  //TK_LHS               = TK_OPERATOR * $22;
  //TK_RHS               = TK_OPERATOR * $23;
  //TK_SUB               = TK_OPERATOR * $24;
  //TK_SUP               = TK_OPERATOR * $25;
  //TK_HEAD              = TK_OPERATOR * $26;
  //TK_TAIL              = TK_OPERATOR * $27;
  //TK_INIT              = TK_OPERATOR * $28;
  //TK_LAST              = TK_OPERATOR * $29;
  //TK_ALL               = TK_OPERATOR * $2A;
  //TK_AT                = TK_OPERATOR * $2F;

  // TK_MIN                = TK_OPERATOR * $30 or TK_BINARY;
  // TK_MAX                = TK_OPERATOR * $31 or TK_BINARY;
  // TK_FLOOR              = TK_OPERATOR * $38;
  // TK_CEIL               = TK_OPERATOR * $39;
  // TK_ROUND              = TK_OPERATOR * $3A;
  // TK_TRUNC              = TK_OPERATOR * $3B;
  // TK_RAND               = TK_OPERATOR * $3C;
  // TK_RANDINT            = TK_OPERATOR * $3D;
  // TK_SQR                = TK_OPERATOR * $40;
  // TK_SQRT               = TK_OPERATOR * $41;
  // TK_ABS                = TK_OPERATOR * $42;
  // TK_SIGN               = TK_OPERATOR * $43;
  // TK_IM                 = TK_OPERATOR * $44;
  // TK_CONJ               = TK_OPERATOR * $45;
  // TK_ARG                = TK_OPERATOR * $46;
  // TK_IMAG               = TK_OPERATOR * $47;
  // TK_REAL               = TK_OPERATOR * $48;
  // TK_CUBE               = TK_OPERATOR * $49;
  // TK_MODULUS            = TK_OPERATOR * $50 or TK_BINARY;
  // TK_EXP                = TK_OPERATOR * $58;
  // TK_LN                 = TK_OPERATOR * $59;
  // TK_LOG2               = TK_OPERATOR * $5A;
  // TK_LOG10              = TK_OPERATOR * $5B;
  // TK_LOGN               = TK_OPERATOR * $5C or TK_BINARY;
  // TK_SIN                = TK_OPERATOR * $60;
  // TK_COS                = TK_OPERATOR * $61;
  // TK_TAN                = TK_OPERATOR * $62;
  // TK_COT                = TK_OPERATOR * $63;
  // TK_SEC                = TK_OPERATOR * $64;
  // TK_CSC                = TK_OPERATOR * $65;
  // TK_ARCSIN             = TK_OPERATOR * $66;
  // TK_ARCCOS             = TK_OPERATOR * $67;
  // TK_ARCTAN             = TK_OPERATOR * $68;
  // TK_SINH               = TK_OPERATOR * $69;
  // TK_COSH               = TK_OPERATOR * $6A;
  // TK_TANH               = TK_OPERATOR * $6B;


  TK_MATCH_MASK         = $00FFFF00;   // ignore meta (TK_DOT)

function IsSelectorToken(TokenId: Integer): Boolean;

implementation

function IsSelectorToken(TokenId: Integer): Boolean;
begin
  Result := (TokenId and TK_SELECTOR_EXTRA_MASK) <> 0;
end;

end.
