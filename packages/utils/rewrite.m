package utils/rewrite;

// Internal callable head used as a staging marker during rewrite pipelines.
callable __apply_head;

// Apply a staged callable head to each comma column (left-to-right).
rule apply_each [
  apply_each [ X -- ]       => utils.rewrite.apply_each all X,
  apply_each { X --, } Y -- =>
    utils.rewrite.__apply_head ( all X ) utils.rewrite.apply_each [ all Y ],
  apply_each { X --, }      => utils.rewrite.__apply_head ( all X )
];

// Lift a rule name/procedure over a list by rebinding the staged head.
rule lift_rule [
  lift_rule proc [ X -- ] => {
    utils.rewrite.apply_each [ all X ]
    $? [ utils.rewrite.__apply_head => proc ]
    : ...
  }
];
