package math/vectors;

/* sum */
rule sum [
  sum X -- => + all X
];

/* product */
rule mul [
  mul X -- => * all X
];

/* kronecker product */
rule kron_scale [
  kron_scale x [ Y -- ] => ( * x Y ) kron_scale x [ rhs Y ],
  kron_scale x []       =>
];

rule kron [
  kron [ X -- ] [ Y -- ] => { kron_scale X [ all Y ] } kron [ rhs X ] [ all Y ],
  kron [] Y              =>,
  kron X []              =>
];

/* flatten */
rule flatten [
  flatten [ x -- ] -- => x flatten [ rhs x ],
  flatten [ X -- ] -- => flatten X flatten [ rhs X ],
  flatten []          =>
];

/* zip */
rule zip [
  zip [ X -- ] [ Y -- ] => [ zip X Y ] zip [ rhs X ] [ rhs Y ],
  zip x y               => x y,
  zip [] []             =>
];

/* dot product */
rule dot [
  dot [ X -- ] [ Y -- ] =>
    sum ( mul X Y )
    dot [ rhs X ] [ rhs Y ],
  dot [] []             =>
];

/* matrix inner product */
rule inner_product [
  inner_product [ RX -- ] [ RY -- ] =>
    sum ( dot RX RY )
    inner_product [ rhs RX ] [ rhs RY ],
  inner_product [] []               =>
];
