package math/axioms;

// axioms
addzero  = + 0            =>           ;
addinv   = + M - M       <=> + 0       ;
commute  = + M N         <=> + N M     ;
mullist  = + m : n       <=> * m n     ;
mulzero  = * m 0         <=> 0         ;
mulone	 = * m 1         <=> m         ;
mulinv	 = * m / m       <=> 1         ;

// definitions
sqrdef   = sqr x          <=> * x x     ;
sqrtdef  = sqrt ( sqr x ) <=> abs x     ;
sgndef   = * ( sgn x ) x  <=> abs x     ;

imdef    = sqr im 1       <=> - 1       ;
expdef   = exp + x y      <=> * ( exp x ) ( exp y ) ;
lnexp    = ln ( exp x )   <=> x         ;
expln    = exp ( ln y )   <=> y         ;
polar    = exp ( im x )   <=> + cos x + im sin x;

// ddx x = 1
// ddx exp x = exp x
