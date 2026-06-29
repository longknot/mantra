package math/subst;

// substitutions
negate   = x ==> ( + - x );

// helpers
addlr    = { U -- <=> V -- } => { + x all U <=> + x all V };
addlr0   = { U -- <=> 0 } => { + x all U <=> + x };

unfold   = ( x )   => op $match x;
fold     = x       => ( x );
