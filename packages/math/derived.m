package math/derived;

// Accepted derived formulas. Proof scripts remain executable documentation of
// these registrations; they are not replayed when a later proof uses a lemma.

// proof/onerepeat.m: 1 repeated n times equals n.
onerepeat = + 1 : + n <=> + n;

// proof/distributive.m: distributive law of repeat under addition..
repdistr = + m n : + p <=> + ( + m : + p ) ( + n : + p );

// proof/repcommute.m: commutativity of repeat under addition.
repcommute = + m : + n <=> + n : + m;

// proof/addinvinv.m: inverse of an inverse is the original number
addinvinv  = + - ( + - x ) <=> + x ;

// proof/invmul.m: inverse of a product is the product of the inverses
invmul = + / ( + * x y ) <=> + * ( + / y ) ( + / x );

// Other potential derived formulas to register:
// addassoc   = + m ( + n p ) <=> + ( + m n ) p;
// multiply   = * m ( + n 1 ) <=> + m * m n ;
// mulcommute = * m n         <=> * n m                 ;
// mulassoc   = * m ( * n p ) <=> * ( * m n ) p         ;
// muldistr   = * m ( + n p ) <=> + ( * m n ) ( * m p ) ;

// next:
// fracmul = * ( / m ) ( / n ) <=> / ( * m n ) ;

// multiply successor:
// * ( + m 1 ) n  <=>  + n ( * m n )
// ( + m 1 ) : n  <=>  + n ( m : n )

// negative product:
// * ( - x ) n <=> - * x n

// fractions:
// * ( / m n ) p <=> * m ( / n p )

// sqrt ( - x )  <=> im * sqrt x

// proof:
// / ( / x ) <=> x

// Definition of a rational number
// + ( / q ) : p


// ### RATIONAL NUMBER ASSOCIATIVITY
// ( (/a : x) : (/b : y) ) : (/c : z)  ==  (/a : x) : ( (/b : y) : (/c : z) )

// property inverse (fractions):
// / ( * x y )  <=>  * ( / x ) ( / y )

// * 64 7 == 448 == 400 + 48 = 4 * 4 *
