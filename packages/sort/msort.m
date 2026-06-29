package sort/msort;

// mantra msort2.m --set input='123 15 33 20 49 12 99 76'

merge_pairs = [
  x y -- => [ [ x ] [ y ] ] [ rhs y ]
];

msort = [
  [ x -- ] [ y -- ] 1     => x [ rhs x ] [ all y ],
  [ x -- ] [ y -- ] 0     => y [ all x ] [ rhs y ],
  [ x -- ] [ y -- ]       => [ all x ] [ all y ] `< x y`,
  [ x -- ] []             => all x,
  [ [ x -- ] ]            => [ all x ],
  []                      =>
];

output = input $? merge_pairs : ...;
