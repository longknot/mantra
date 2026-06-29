package utils/cat_impl;

rule cat [
  cat [ X -- ] => [ all X ],
  cat [ X -- ] [ Y -- ] => cat [ all X all Y ],
  cat [ X -- ] [ Y -- ] Z -- => cat [ all X all Y ] all Z
];
