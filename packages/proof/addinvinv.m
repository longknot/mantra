package proof/addinvinv;

import utils;
import math;

{ mantra.inference.beam = 63 }
{ mantra.inference.budget = 4 }
{ max_steps = 6 }

{ addinv_x = math.addinv ? [ M ==> x ] }
{ addinvinv_x = math.addinvinv ? [ m ==> x ] }

rules = [
  math.negate,
  math.unfold,
  math.addzero,
  forward math.addinv,
  math.addlr
];

{ W = addinv_x => addinvinv_x ?|= rules : max_steps }

printf "%s" [ utils.witness_render_steps_wide W ];
