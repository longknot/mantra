package utils/witness;

import utils/trie;

// Default one-line format used by witness_step_text.
witness_line_fmt = "step %s | rule=%s | dir=%s | anchor=%d | %t => %t";

// Declarative compact tabular render profile for witness step lists.
global profiles.witness_steps.kind = "tabular";
global profiles.witness_steps.options.header = 1;
global profiles.witness_steps.rows.kind = "trie_children";
global profiles.witness_steps.rows.path_suffix = ".steps";
{ global assign_path "profiles.witness_steps.columns[1]" ( name -> "STEP", kind -> "path_segment", index -> -1 ) };
{ global assign_path "profiles.witness_steps.columns[2]" ( name -> "RULE", kind -> "relative_get", path -> ".rule_name" ) };
{ global assign_path "profiles.witness_steps.columns[3]" ( name -> "DIR", kind -> "relative_get", path -> ".direction" ) };
{ global assign_path "profiles.witness_steps.columns[4]" ( name -> "ANCHOR", kind -> "relative_get", path -> ".anchor" ) };

// Declarative wide tabular render profile for witness step lists.
global profiles.witness_steps_wide.kind = "tabular";
global profiles.witness_steps_wide.options.header = 1;
global profiles.witness_steps_wide.rows.kind = "trie_children";
global profiles.witness_steps_wide.rows.path_suffix = ".steps";
{ global assign_path "profiles.witness_steps_wide.columns[1]" ( name -> "STEP", kind -> "path_segment", index -> -1 ) };
{ global assign_path "profiles.witness_steps_wide.columns[2]" ( name -> "RULE", kind -> "relative_get", path -> ".rule_name" ) };
{ global assign_path "profiles.witness_steps_wide.columns[3]" ( name -> "DIR", kind -> "relative_get", path -> ".direction" ) };
{ global assign_path "profiles.witness_steps_wide.columns[4]" ( name -> "ANCHOR", kind -> "relative_get", path -> ".anchor" ) };
{ global assign_path "profiles.witness_steps_wide.columns[5]" ( name -> "BEFORE", kind -> "relative_get", path -> ".before" ) };
{ global assign_path "profiles.witness_steps_wide.columns[6]" ( name -> "AFTER", kind -> "relative_get", path -> ".after" ) };

// Formats one witness step as a single string.
rule witness_step_text [
  witness_step_text S -- => fmt $utils.witness.witness_line_fmt [
    { path_segment S -1 }
    { get { fmt "%s.rule_name" [ S ] } }
    { get { fmt "%s.direction" [ S ] } }
    { get { fmt "%s.anchor" [ S ] } }
    { get { fmt "%s.before" [ S ] } }
    { get { fmt "%s.after" [ S ] } }
  ]
];

// Prints one witness step line.
rule witness_print_step [
  witness_print_step S -- => ( printf "%s" [ utils.witness.witness_step_text S ] )
];

// Walks a witness step path list and prints each step on its own line.
rule witness_print_steps_walk [
  witness_print_steps_walk [ x -- ] =>
    [ utils.witness.witness_print_step x ]
    utils.witness.witness_print_steps_walk [ rhs x ],
  witness_print_steps_walk [] => []
];

// Prints all witness steps for a witness handle.
rule witness_print_steps [
  witness_print_steps W -- =>
    utils.witness.witness_print_steps_walk [
      { query_children { fmt "%s.steps" [ W ] } }
    ]
];

// Renders all witness steps as a columns table string.
rule witness_render_steps [
  witness_render_steps W -- => render columns profiles.witness_steps W
];

// Renders all witness steps as a wide columns table string.
rule witness_render_steps_wide [
  witness_render_steps_wide W -- => render columns profiles.witness_steps_wide W
];

// Renders all witness steps as a CSV string.
rule witness_render_steps_csv [
  witness_render_steps_csv W -- => render csv profiles.witness_steps W
];

// Renders all witness steps as a wide CSV string.
rule witness_render_steps_wide_csv [
  witness_render_steps_wide_csv W -- => render csv profiles.witness_steps_wide W
];
