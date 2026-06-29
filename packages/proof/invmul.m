package proof/invmul;

import utils;

{ mantra.inference.beam = 5 }
{ max_steps = 4 }

invmul = + / ( + * x y ) <=> + * ( + / y ) ( + / x );

mullr = { U -- <=> V -- } => { + * x y all U <=> + * x y all V };
mulinv = + * m ( + / m ) => + * 1;
mulone = + * m 1 => + * m;

rules = [ mullr, mulinv, mulone ]

{ r1 = [ mullr ] }
{ r2 = [ mulinv ] }
{ r3 = [ mulone ] }

{ target = invmul ? r1 ? r2 ? r3 ? r2 }
{ W = invmul => target ?|= rules : max_steps }

printf "%s" [ utils.witness_render_steps_wide W ];
