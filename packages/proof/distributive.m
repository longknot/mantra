// DISTRIBUTIVE PROPERTY, BY INDUCTION ON p
//
// Proof-friendly shape for the current engine:
// - materialize both sides of P(m, n, 1)
// - treat the more expanded RHS as the proof subject
// - contract it to the canonical LHS form
//
// This avoids asking inference to expand `+ m n : + 1` into the distributive RHS.
// Instead, both sides are evaluated once, and the base case is proved by
// normalization of the expanded side. The successor proof reuses that
// proved base instance separately from the fixed local induction hypothesis.

import math;
import utils;

{ mantra.inference.beam = 7 }
{ mantra.inference.anchors_per_rule = 2 }
//{ mantra.inference.policy = "cost" }
{ max_steps = 3 }

proposition = << + m n : + p >> => << + ( + m : + p ) ( + n : + p ) >>;
ih = \ proposition;
rules_1 = [
	forward math.auxiliary.repeat1,
  math.auxiliary.repeat1_rev
];

{ math.induction.prove_by_induction proposition [ p ==> + 1 ] rules_1 }

printf "=== BASE CASE ===";
printf "%s" [ utils.witness_render_steps_wide W ];

// Add the proved p = 1 instance as a lemma for the successor proof.
{ base_case = proposition ? [ p ==> + 1 ] }

{ mantra.inference.beam = 25 }
{ mantra.inference.anchors_per_rule = 2 }
{ max_steps = 8 }

rules_p1 = [
  math.auxiliary.repeat_seq,
  ih,
  base_case,
  math.auxiliary.flatten,
  math.axioms.commute,
	math.auxiliary.repeat_rev
];

{ math.induction.prove_by_induction proposition [ p ==> + p 1 ] rules_p1 }

printf ""
printf "=== INDUCTION STEP ===";
printf "%s" [ utils.witness_render_steps_wide W ];
