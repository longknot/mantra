# Known Limitations

Mantra is an experimental alpha release. It is suitable for exploration,
language experiments, and controlled local use. Syntax, semantics, command-line
options, package behavior, and internal APIs may change without notice.

## Language Semantics

- Some behavior is defined primarily by the current implementation and fixture
  suite rather than a complete formal language specification.
- Rewriting, selection, nested evaluation, and inference still have edge cases
  whose canonical behavior is being stabilized.
- Equivalent-looking tree forms may not always normalize or participate in
  matching and inference identically.
- Error messages and rejection behavior are not yet consistent across all
  malformed or unsupported forms.

## Local Scopes and Namespaces

- `scope { ... }` provides lexical local values for exact, simple names.
- Dotted or trie-shaped paths are not frame-local. They continue to use
  namespace/package path resolution.
- Dynamic setting overrides are not yet integrated into local scope frames.
- Local callables and local rule definitions are not supported.
- Debugger output does not always explain whether a value came from a local
  frame, package namespace, or base/global state.

## Rewriting and Inference

- Inference is incomplete: a valid proof or rewrite path may exist without
  being discovered by the current search.
- Search results can be sensitive to expression shape, normalization, search
  budgets, and frontier pruning.
- Inference diagnostics do not yet provide a complete explanation of rejected,
  omitted, or pruned paths.
- Complex head dispatch and capture patterns may have surprising edge cases.

## Packages and Modules

- Package manifests, dependency metadata, version constraints, import aliases,
  exports, and private visibility are not final.
- Package and module loading should be treated as an evolving experimental
  interface.
- Loading untrusted packages or source files is not considered safe.

## Runtime and Performance

- Performance has not been systematically optimized or benchmarked.
- Large rewrites and proof searches may consume substantial CPU time and
  memory.
- Rule indexing and performance instrumentation are limited.
- Crafted or expansive rules can produce runaway growth or long-running
  searches. Use conservative inference and rewrite budgets.

## Tooling and Platform Support

- The primary supported build environment is Free Pascal on a POSIX-like
  system targeting `x86_64`.
- Other operating systems, architectures, and Free Pascal versions may work
  but are not regularly validated.
- The HTTP server and MCP server are alpha interfaces and should not be exposed
  directly to untrusted networks.
- Debugger and diagnostic coverage is incomplete.

## Compatibility

There are no source, binary, package, protocol, or serialized-data compatibility
guarantees during alpha. Pin the exact commit when using Mantra in reproducible
experiments.

Please report reproducible problems using the guidance in
[CONTRIBUTING.md](CONTRIBUTING.md). Report security-sensitive problems using
[SECURITY.md](SECURITY.md).
