package utils;

import utils/cat_impl;
import utils/rewrite;
import utils/trie;
import utils/witness;

witness_line_fmt = utils.witness.witness_line_fmt;

rule cat [
  cat ARGS -- => { utils.cat_impl.cat all ARGS }
];

rule apply_each [
  apply_each ARGS -- => { utils.rewrite.apply_each all ARGS }
];

rule lift_rule [
  lift_rule ARGS -- => { utils.rewrite.lift_rule all ARGS }
];

rule dict_keys [
  dict_keys ARGS -- => { utils.trie.dict_keys all ARGS }
];

rule dict_values [
  dict_values ARGS -- => { utils.trie.dict_values all ARGS }
];

rule dict_children [
  dict_children ARGS -- => { utils.trie.dict_children all ARGS }
];

rule trie_child_path [
  trie_child_path ARGS -- => { utils.trie.trie_child_path all ARGS }
];

rule trie_index_path [
  trie_index_path ARGS -- => { utils.trie.trie_index_path all ARGS }
];

rule trie_next_index [
  trie_next_index ARGS -- => { utils.trie.trie_next_index all ARGS }
];

rule trie_assign_child [
  trie_assign_child ARGS -- => { utils.trie.trie_assign_child all ARGS }
];

rule trie_assign_indexed [
  trie_assign_indexed ARGS -- => { utils.trie.trie_assign_indexed all ARGS }
];

rule flat_to_nested_entry [
  flat_to_nested_entry ARGS -- => { utils.trie.flat_to_nested_entry all ARGS }
];

rule flat_to_nested_fold [
  flat_to_nested_fold ARGS -- => { utils.trie.flat_to_nested_fold all ARGS }
];

rule flat_to_nested [
  flat_to_nested ARGS -- => { utils.trie.flat_to_nested all ARGS }
];

rule trie_object_task [
  trie_object_task ARGS -- => { utils.trie.trie_object_task all ARGS }
];

rule trie_value_task [
  trie_value_task ARGS -- => { utils.trie.trie_value_task all ARGS }
];

rule trie_array_task [
  trie_array_task ARGS -- => { utils.trie.trie_array_task all ARGS }
];

rule make_trie [
  make_trie ARGS -- => { utils.trie.make_trie all ARGS }
];

rule trie_to_ast [
  trie_to_ast ARGS -- => { utils.trie.trie_to_ast all ARGS }
];

rule trie_to_ast_children [
  trie_to_ast_children ARGS -- => { utils.trie.trie_to_ast_children all ARGS }
];

rule witness_step_text [
  witness_step_text ARGS -- => { utils.witness.witness_step_text all ARGS }
];

rule witness_print_step [
  witness_print_step ARGS -- => { utils.witness.witness_print_step all ARGS }
];

rule witness_print_steps_walk [
  witness_print_steps_walk ARGS -- => { utils.witness.witness_print_steps_walk all ARGS }
];

rule witness_print_steps [
  witness_print_steps ARGS -- => { utils.witness.witness_print_steps all ARGS }
];

rule witness_render_steps [
  witness_render_steps ARGS -- => { utils.witness.witness_render_steps all ARGS }
];

rule witness_render_steps_wide [
  witness_render_steps_wide ARGS -- => { utils.witness.witness_render_steps_wide all ARGS }
];

rule witness_render_steps_csv [
  witness_render_steps_csv ARGS -- => { utils.witness.witness_render_steps_csv all ARGS }
];

rule witness_render_steps_wide_csv [
  witness_render_steps_wide_csv ARGS -- => { utils.witness.witness_render_steps_wide_csv all ARGS }
];
