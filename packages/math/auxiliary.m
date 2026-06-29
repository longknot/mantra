package math/auxiliary;

// Oriented rules used to expose and rebuild repeat structure during search.
// These are intentionally separate from axioms while their relationship to
// more compact repeat formulas is still being analyzed.

repeat   = X : + m n  <=> + ( X : + m ) ( X : + n ) ;
repeat0  = X : + 0    <=>           ;

repeat_seq = X -- : + m n => + ( all X : + m ) ( all X : + n );
repeat_rev = + ( Y : + m ) ( Y : + n ) => + ( Y : + m n );

repeat1   = + x -- : + 1 <=> + x --;
repeat1_1 = + n : + 1 <=> + n;

repeat1_rev = + x => + ( + x : + 1 );

flatten = + ( + A -- ) => + A --;
flatten_1 = + ( A -- ) => A --;
