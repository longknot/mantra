# Transformations and Repeat

Transformations are the rewrite layer of Mantra. The colon operator expands
trees, selection rewrites subjects with rules, and inference searches for
proofs over those rewrites.

## Topics

Start here if you want the core rewrite operators:

- [Repeat Operator](repeat-operator.md) - `:` cloning, bounded repeat, fixpoint repeat, and staged repeat
- [Selection](selection.md) - `?`, `:=?`, root selection, guards, and rewrite strategy
- [Inference](inference.md) - `|=` and `?|=` proof search, witnesses, and bounded search
- [Patterns](patterns.md)
- [Transform Rules](transform-rules.md)
- [Rules in Practice](rules-in-practice.md)
- [Common Repeat Examples](common-repeat-examples.md)
- [Expansion Behavior](expansion-behavior.md)
- [Nested Repeats](nested-repeats.md)
- [Repeat with Evaluation Scopes](repeat-with-evaluation-scopes.md)
- [Repeat with Compute Scopes](repeat-with-compute-scopes.md)
- [Staged Repeat](staged-repeat.md)

## Reading Order

If you are learning the transformation model, a useful order is:

1. Repeat operator `:` for cloning and iteration.
2. Selection `?` and `:=?` for single-step rewrites.
3. State selection `$?` for repeated rewrite loops.
4. Inference `|=` and `?|=` for bounded proof search.

That sequence matches the way the runtime moves from structural expansion to
rule application and finally to proof search.
