package math/calculus;

// First differentiation milestone: formal derivative with respect to literal x.
// Consuming proof scopes should also define calculus symbols they intend to be
// literal, for example `define ddx exp x y;`, before applying these rules.
define ddx exp x;

ddx_self = ddx x => 1;

// Numeric literal constants.
ddx_zero = ddx 0 => 0;
ddx_one = ddx 1 => 0;

// Structural derivative rules. Keep this conservative until operator-carried
// captures are normalized for calculus proofs.
ddx_exp = ddx ( exp A ) => * ( exp A ) ( ddx A );

// Local cleanup helpers useful in early derivative proofs.
mulone_l = * 1 A => A;
