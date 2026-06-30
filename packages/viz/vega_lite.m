package viz/vega_lite;

mime = "application/vnd.vegalite.v6+json";
schema = "https://vega.github.io/schema/vega-lite/v6.json";
__line_row = 1;

// Materializes a basic line-chart specification at SPEC.
// Callers place row objects under SPEC.data.values[n].
rule line_xy [
  line_xy SPEC X Y -- => {
    { assign_path "" { fmt "%s.$schema" [ SPEC ] } $viz.vega_lite.schema },
    { assign_path "" { fmt "%s.mark" [ SPEC ] } "line" },
    { assign_path "" { fmt "%s.encoding.x.field" [ SPEC ] } X },
    { assign_path "" { fmt "%s.encoding.x.type" [ SPEC ] } "quantitative" },
    { assign_path "" { fmt "%s.encoding.y.field" [ SPEC ] } Y },
    { assign_path "" { fmt "%s.encoding.y.type" [ SPEC ] } "quantitative" }
  } SPEC
];

// Materializes y = EXPR over a staged sequence or range driver bound to x.
rule line_range [
  line_range SPEC RANGE EXPR SERIES -- => {
    { viz.vega_lite.line_xy SPEC "x" "y" },
    { assign_path "" { fmt "%s.encoding.color.field" [ SPEC ] } "series" },
    { assign_path "" { fmt "%s.encoding.color.type" [ SPEC ] } "nominal" },
    { viz.vega_lite.line_range_series SPEC RANGE EXPR SERIES }
  } SPEC,
  line_range SPEC RANGE EXPR -- => {
    { viz.vega_lite.line_xy SPEC "x" "y" },
    { viz.vega_lite.__line_row = 1 },
    { viz.vega_lite.line_range_values SPEC RANGE EXPR }
  } SPEC
];

rule line_range_values [
  line_range_values SPEC RANGE EXPR -- => {
    [ scope {
        { assign_path { fmt "%s.data.values[%s].x" [ SPEC $viz.vega_lite.__line_row ] } x },
        { assign_path { fmt "%s.data.values[%s].y" [ SPEC $viz.vega_lite.__line_row ] } { ~ + ( EXPR ) } },
        { assign_path "viz.vega_lite.__line_row" { ~ + $viz.vega_lite.__line_row 1 } }
    } ] :: RANGE @ x
  }
];

rule line_range_series [
  line_range_series SPEC RANGE EXPR SERIES -- => {
    [ scope {
        { assign_path { fmt "%s.data.values[%s].x" [ SPEC $viz.vega_lite.__line_row ] } x },
        { assign_path { fmt "%s.data.values[%s].y" [ SPEC $viz.vega_lite.__line_row ] } { ~ + ( EXPR ) } },
        { assign_path { fmt "%s.data.values[%s].series" [ SPEC $viz.vega_lite.__line_row ] } SERIES },
        { assign_path "viz.vega_lite.__line_row" { ~ + $viz.vega_lite.__line_row 1 } }
    } ] :: RANGE @ x
  }
];

rule square_range [
  square_range SPEC RANGE -- => {
    viz.vega_lite.line_range SPEC RANGE ( * x x )
  }
];

// Emits a Vega-Lite MIME output in sessions and JSON text in the CLI.
rule show [
  show SPEC -- => ( display $viz.vega_lite.mime SPEC )
];
