package sort/msort_codex;

wrap_runs = [
  x y     => [ x ] y,
  [ a ] x => [ a ] [ x ]
];

merge = [
  [ x -- ] [ y -- ] 1     => x [ rhs x ] [ all y ],
  [ x -- ] [ y -- ] 0     => y [ all x ] [ rhs y ],
  [ x -- ] [ y -- ]       => [ all x ] [ all y ] `< x y`,
  [ x -- ] []             => all x,
  [] [ y -- ]             => all y
];

fold_runs = [
  [ x -- ] [ y -- ] => [ [ all x ] [ all y ] $? sort.msort_codex.merge : ... ]
];

unwrap = [
  [ x -- ] => all x
];

runs = input $? sort.msort_codex.wrap_runs : ...;

sorted_run = runs $? sort.msort_codex.fold_runs : ...;
