package main;
import sort;

input = 123 15 33 20 49 12 99 76;

print {
  input $? sort.msort_codex.wrap_runs : ...
        $? sort.msort_codex.fold_runs : ...
        $? sort.msort_codex.unwrap : 1
};
