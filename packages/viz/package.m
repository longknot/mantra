package viz;

import viz/vega_lite;

vega_lite_mime = viz.vega_lite.mime;
vega_lite_schema = viz.vega_lite.schema;

rule line_xy [
  line_xy ARGS -- => { viz.vega_lite.line_xy all ARGS }
];

rule line_range [
  line_range ARGS -- => { viz.vega_lite.line_range all ARGS }
];

rule square_range [
  square_range ARGS -- => { viz.vega_lite.square_range all ARGS }
];

rule show [
  show ARGS -- => { viz.vega_lite.show all ARGS }
];
