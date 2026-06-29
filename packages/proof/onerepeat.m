/*

P(n):
proposition = + 1 : + n <=> + n;

IH available in the successor proof:
ih = \ proposition;

P(+ n 1):
+ 1 : + n 1 <=> + n 1

+ ( + 1 : + n ) ( + 1 : + 1 )   // repeat_seq
+ ( + 1 : + n ) ( + 1 )         // repeat1
+ ( + n ) ( + 1 )               // ih

*/

import math;
import utils;

{ mantra.inference.beam = 3 }
{ mantra.inference.anchors_per_rule = 2 }
{ max_steps = 5 }

proposition = << + 1 : + n >> <=> << + n >>;
ih = \ proposition;

rules_1 = [
  forward math.auxiliary.repeat1
];

{ math.induction.prove_by_induction proposition [ n ==> + 1 ] rules_1 }

printf "=== BASE CASE ===";
printf "%s" [ utils.witness_render_steps_wide W ];

rules_p1 = [
  math.auxiliary.repeat_seq,
  forward math.auxiliary.repeat1,
  ih,
  math.auxiliary.flatten
];

{ math.induction.prove_by_induction proposition [ n ==> + n 1 ] rules_p1 }

printf ""
printf "=== INDUCTION STEP ===";
printf "%s" [ utils.witness_render_steps_wide W ];
