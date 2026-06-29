package math;

import math/auxiliary;
import math/axioms;
import math/calculus;
import math/constants;
import math/derived;
import math/induction;
import math/keywords;
import math/subst;
import math/vectors;

addzero = math.axioms.addzero;
addinv = math.axioms.addinv;
commute = math.axioms.commute;
mullist = math.axioms.mullist;
mulzero = math.axioms.mulzero;
mulone = math.axioms.mulone;
mulinv = math.axioms.mulinv;
sqrdef = math.axioms.sqrdef;
sqrtdef = math.axioms.sqrtdef;
sgndef = math.axioms.sgndef;
imdef = math.axioms.imdef;
expdef = math.axioms.expdef;
lnexp = math.axioms.lnexp;
expln = math.axioms.expln;
polar = math.axioms.polar;

onerepeat = math.derived.onerepeat;
repdistr = math.derived.repdistr;
repcommute = math.derived.repcommute;
addinvinv = math.derived.addinvinv;
invmul = math.derived.invmul;

golden_mean = math.constants.golden_mean;
sqrt_2 = math.constants.sqrt_2;
exp_cf = math.constants.exp_cf;
pi = math.constants.pi;

induction_extract_subject = math.induction.induction_extract_subject;
induction_extract_target = math.induction.induction_extract_target;

negate = math.subst.negate;
addlr = math.subst.addlr;
addlr0 = math.subst.addlr0;
unfold = math.subst.unfold;
fold = math.subst.fold;

ddx_self = math.calculus.ddx_self;
ddx_zero = math.calculus.ddx_zero;
ddx_one = math.calculus.ddx_one;
ddx_exp = math.calculus.ddx_exp;
ddx_mulone_l = math.calculus.mulone_l;

rule induction_step_hypothesis [
  induction_step_hypothesis ARGS -- => { math.induction.induction_step_hypothesis all ARGS }
];

rule induction_step_subject [
  induction_step_subject ARGS -- => { math.induction.induction_step_subject all ARGS }
];

rule induction_step_target [
  induction_step_target ARGS -- => { math.induction.induction_step_target all ARGS }
];

rule sum [
  sum ARGS -- => { math.vectors.sum all ARGS }
];

rule mul [
  mul ARGS -- => { math.vectors.mul all ARGS }
];

rule kron [
  kron ARGS -- => { math.vectors.kron all ARGS }
];

rule flatten [
  flatten ARGS -- => { math.vectors.flatten all ARGS }
];

rule zip [
  zip ARGS -- => { math.vectors.zip all ARGS }
];

rule dot [
  dot ARGS -- => { math.vectors.dot all ARGS }
];

rule inner_product [
  inner_product ARGS -- => { math.vectors.inner_product all ARGS }
];
