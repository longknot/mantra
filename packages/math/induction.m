package math/induction;

// Extract the subject side from an instantiated induction hypothesis.
induction_extract_subject = { X -- => Y -- } => all X;

// Extract the target side from an instantiated induction hypothesis.
induction_extract_target = { X -- => Y -- } => all Y;

// Instantiate an induction hypothesis with a successor substitution.
rule induction_step_hypothesis [
  induction_step_hypothesis SUCC IH -- => { IH ? SUCC }
];

// Build the instantiated induction-step subject.
//
// Usage note:
// materialize the result before inference, e.g.
//   { subject = induction_step_subject succ ih };
rule induction_step_subject [
  induction_step_subject SUCC IH -- =>
    {
      math.induction.induction_step_hypothesis SUCC IH
      ? math.induction.induction_extract_subject
    }
];

// Build the instantiated induction-step target.
//
// Usage note:
// materialize the result before inference, e.g.
//   { target = induction_step_target succ ih };
rule induction_step_target [
  induction_step_target SUCC IH -- =>
    {
      math.induction.induction_step_hypothesis SUCC IH
      ? math.induction.induction_extract_target
    }
];

// Generic proof driver. The proposition is instantiated by V; local fixed
// hypotheses and base-case lemmas remain entries in the caller's ruleset.
rule prove_by_induction [
  prove_by_induction P V R => {
    { goal = P ? V },
    { W = goal ?|= R : max_steps }
  }
];
