import math;
import utils;

{ mantra.inference.beam = 3 }
{ mantra.inference.anchors_per_rule = 2 }
{ max_steps = 5 }

proposition = << + m : + n >> => << + n : + m >>;
ih = \ proposition;

rules_1 = [
  math.auxiliary.repeat1_1,
  math.derived.onerepeat
];

{ math.induction.prove_by_induction proposition [ m ==> + 1 ] rules_1 }

printf "=== BASE CASE ===";
printf "%s" [ utils.witness_render_steps_wide W ];

// Add the proved base instance as a lemma for the successor proof.
{ base_case = proposition ? [ m ==> + 1 ] }

rules_p1 = [
  forward math.derived.repdistr,
  ih,
  base_case,
  math.auxiliary.repeat_rev,
  math.auxiliary.flatten_1
];

{ math.induction.prove_by_induction proposition [ m ==> + m 1 ] rules_p1 }

printf ""
printf "=== INDUCTION STEP ===";
printf "%s" [ utils.witness_render_steps_wide W ];
