package utils/trie;

// Returns the direct child keys under a trie path.
rule dict_keys [
  dict_keys X -- => query_keys X
];

// Returns the direct child values under a trie path.
rule dict_values [
  dict_values X -- => query_values X
];

// Returns the direct child paths under a trie path.
rule dict_children [
  dict_children X -- => query_children X
];

// Joins a trie path and a child key with dot notation.
rule trie_child_path [
  trie_child_path path X -- => fmt "%s.%s" [ path X ]
];

// Builds an indexed trie path like `path[3]`.
rule trie_index_path [
  trie_index_path path I -- => {
    implode { fmt "%s" [ path ] } "[" { fmt "%s" [ { ~ I } ] } "]"
  }
];

// Advances an array index using the grouped compute shape.
rule trie_next_index [
  trie_next_index I -- => { ~ { + I 1 } }
];

// Assigns a value to a child path derived from a root path and key.
rule trie_assign_child [
  trie_assign_child path X V -- => {
    assign_path "" { utils.trie.trie_child_path path X } V
  }
];

// Assigns a value to an indexed path derived from a root path and index.
rule trie_assign_indexed [
  trie_assign_indexed path I V -- => {
    assign_path "" { utils.trie.trie_index_path path I } V
  }
];

// Assigns one flat trie entry under an optional root.
rule flat_to_nested_entry [
  flat_to_nested_entry ROOT E -- => assign_path { fmt "%s" [ ROOT ] } ( E )
];

// Folds a flat list of trie entries into nested trie state.
rule flat_to_nested_fold [
  flat_to_nested_fold ROOT [ E Rest -- ] =>
    { utils.trie.flat_to_nested_entry ROOT E }
    utils.trie.flat_to_nested_fold ROOT [ all Rest ],
  flat_to_nested_fold ROOT [ E -- ]      => { utils.trie.flat_to_nested_entry ROOT E },
  flat_to_nested_fold ROOT []            => []
];

// Converts a flat list of path/value entries into a nested trie.
rule flat_to_nested [
  flat_to_nested ROOT FLAT -- => { utils.trie.flat_to_nested_fold ROOT FLAT } ROOT
];


// Walks one object-like trie payload and delegates each field to trie_value_task.
rule trie_object_task [
  trie_object_task [ path { X -> Y, } . -- ] => {
    utils.trie.trie_value_task [ { utils.trie.trie_child_path path X } Y ],
    utils.trie.trie_object_task [ path { $focus } ]
  },
  trie_object_task [ path { X -> Y } ] => {
    utils.trie.trie_value_task [ { utils.trie.trie_child_path path X } Y ]
  },
  trie_object_task [ path {} ] => []
];

// Materializes a trie value, descending into objects and arrays when needed.
rule trie_value_task [
  trie_value_task [ path { X --, } ] => { utils.trie.trie_object_task [ path { all X } ] },
  trie_value_task [ path { X -> Y } ] => { utils.trie.trie_object_task [ path { X -> Y } ] },
  trie_value_task [ path [ X Y -- ] ] => {
    { utils.trie.trie_assign_indexed path 1 ( X ) },
    utils.trie.trie_array_task [ path 2 [ all Y ] ]
  },
  trie_value_task [ path [ X -- ] ] => {
    { utils.trie.trie_assign_indexed path 1 ( X ) }
  },
  trie_value_task [ path [] ] => [],
  trie_value_task [ path V ] => { assign_path path V }
];

// Materializes the remaining items of an array-like trie payload.
rule trie_array_task [
  trie_array_task [ path I [ X Y -- ] ] => {
    { utils.trie.trie_assign_indexed path I ( X ) },
    utils.trie.trie_array_task [ path { utils.trie.trie_next_index I } [ all Y ] ]
  },
  trie_array_task [ path I [ X -- ] ] => {
    { utils.trie.trie_assign_indexed path I ( X ) }
  },
  trie_array_task [ path I [] ] => []
];

// Builds trie state from a nested variable-subtree source rooted at `K`.
rule make_trie [
  make_trie { K -> V } => { utils.trie.trie_object_task [ K { V } ] } K
];

// Converts trie children into an AST-like pair structure.
rule trie_to_ast [
  trie_to_ast [ x y -- ] => { utils.trie.trie_to_ast [ x ] , utils.trie.trie_to_ast [ all y ] },
  trie_to_ast [ x ] => {
    make_pair {
      path_segment $x -1
    } {
      utils.trie.trie_to_ast_children { $x -> [ { query_children $x } ] }
    }
  }
];

// Converts one trie child payload into either a nested AST list or a leaf value.
rule trie_to_ast_children [
  trie_to_ast_children { x -> [ y -- ] } => { [ utils.trie.trie_to_ast [ all y ] ] },
  trie_to_ast_children { x -> [] } => { get x }
];
