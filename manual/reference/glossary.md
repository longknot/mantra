# Glossary

## Abstract Syntax Tree

The tree representation of a parsed Mantra program. Source text is tokenized,
parsed, and built into an AST composed of `TTreeNode` records in a pooled
array. The AST is then rewritten and evaluated in place rather than compiled
to bytecode.

See [Language Model](../language-model/index.md) and [Programs as Trees](../language-model/programs-as-trees.md).

## Array / List

Square brackets `[ ... ]` create an array (list) node that holds ordered
elements. Arrays are first-class tree nodes — they can be inspected, cloned,
and transformed like any other node.

See [List Containers](../syntax/list-containers.md).

## Assignment

The `=` operator binds a variable name to a tree snapshot. The value is stored
as a deep clone of the right-hand subtree in the runtime context. Later
references to the variable substitute by cloning the stored tree. Use `:=` for
deep assignment (evaluating the right side before storing).

See [Assignment Syntax](../syntax/operators-special-forms/assignment-syntax.md).

## Beam Search

An inference strategy that retains multiple candidate rewrite paths at each
step rather than committing to the first match. The beam width controls how
many candidates survive; the default is `1` (greedy, single-path). Widening
the beam increases coverage at the cost of search time.

See [Inference](../transformations/inference.md).

## Callable

A named, reusable block of rules or logic invoked by name. Callables are
declared with the `callable` keyword and dispatched during evaluation.
Breakpoints can be set on callables via `--break-callable`.

See [Callable Declaration](../syntax/keywords-declarations.md).

## Concatenation (`&`)

The `&` operator joins sequences end-to-end. It concatenates arrays, character
sequences, and tree structures. Used with `explode`/`implode` for string
manipulation.

## Code-as-Data (Homoiconicity)

The principle that Mantra programs and their data share the same tree
representation. Source code is parsed into AST nodes; those same nodes are
manipulated as data during execution. There is no distinction between "code"
and "data" at the tree level — everything is a node.

See [Language Model](../language-model/index.md).

## Compute Scope

A backtick-delimited scope `` ` ... ` `` that asks the runtime to reduce
supported operations (arithmetic, boolean, comparisons, trigonometric
functions, etc.) within the enclosed expression.

See [Compute Scopes](../syntax/compute-scopes.md) and [Compute](../compute/index.md).

## Congruence Budget

An inference setting that limits how many subexpression rewrites are considered
per search step. Budget `0` restricts matching to the root only; `1` allows
one subexpression rewrite per step; `-1` (default) means unlimited. CLI flag:
`--congruence-budget`.

See [Inference](../transformations/inference.md).

## Context (Runtime Variable Context)

The runtime environment that stores variable bindings. Each variable maps to a
cloned tree snapshot. The context is read during evaluation to resolve variable
references and is modified by assignment operators. It also holds inference
configuration variables (`mantra.inference.*`) and debugger state.

## Evaluation Scope

A curly-brace-delimited scope `{ ... }` that marks an expression for evaluation.
Inside an evaluation scope, the runtime resolves variables, processes operators,
applies transformations, and collapses the scope on completion. Without evaluation
scopes, forms remain structural and are not automatically computed.

See [Evaluation Scopes](../syntax/evaluation-scopes.md).

## EOT (End-of-Tree)

The sentinel value `MaxInt` used to indicate "no link" in tree edges. When a
node's `LHS` (left child) or `RHS` (right sibling) is `EOT`, that edge is
empty. Also used as `PrevIndex` to mark a root node with no parent context,
which distinguishes `Expand` from `ExpandInline`.

## Expression

A grouped language form delimited by parentheses `( ... )`. Expressions create
expression nodes in the AST. Square brackets `[ ... ]` create array/list nodes,
while curly braces `{ ... }` create evaluation scopes and backticks
`` ` ... ` `` create compute scopes — each scope delimiter produces a distinct
node type.

See [Expressions](../syntax/expressions.md) and [Scope Nodes](../language-model/programs-as-trees/scope-nodes.md).

## Evaluation Lifecycle

The fixed sequence of phases each node passes through: `Execute` (recursive
traversal), `Evaluate` (variable resolution, scope processing, transforms),
`Compute` (arithmetic reduction in backtick scopes), and `Complete` (cleanup).
During evaluation, nodes can be expanded, deleted, or cloned — the tree
mutates in place.

See [Evaluation Model](../language-model/evaluation-model.md).

## Fixed Scope

Single quotes `' ... '` mark a fixed scope — the subtree inside is not evaluated
or transformed. Nodes inside single quotes retain their original structure. The
backslash prefix `\` on a single node has the same fixed effect without requiring
a scope delimiter.

See [Fixed Scopes](../syntax/fixed-scopes.md).

## Fixpoint / Recurse (`...`)

The triple-dot operator `...` signals unbounded iteration — the runtime repeats
a transformation until no more matches occur. All fixpoint iterations are hard-
capped at `MAX_FIXPOINT_STEPS` (1024) to prevent infinite loops. Also used with
the repeat operator for recursive expansion.

See [Fixpoint Repeat](../transformations/repeat-operator/fixpoint-repeat.md).

## Formatter

The formatting subsystem (`formatters.pas`) that converts an AST tree back into
a readable string representation for output. Formatters handle each node type,
preserving scope delimiters, operator symbols, and structural indentation.

## Full-Match Mode (`^`)

The `^` meta flag forces a selection rule to match the entire root expression
rather than any subexpression. By default, rules probe inside the tree; with
`^`, only the top-level structure is considered.

See [Meta Flags](../syntax/meta-flags.md) and [Root Selection](../transformations/selection/root-selection.md).

## Inference

Bounded proof search over tree rewrites. The `|=` operator checks whether a set
of rules can transform a subject expression into a target expression, returning
`1` (success) or `0` (failure). Supports beam search, congruence budgeting,
step bounds, and materialized witness traces (`?|=`). The query can be directional
(`=>`) or bidirectional (`<=>`).

See [Inference](../transformations/inference.md).

## Left-Child / Right-Sibling

The tree representation used by Mantra's `TTreeNode`. Each node carries only two
edges: `LHS` (first child) and `RHS` (next sibling). There are no parent pointers.
Any n-arity tree is encoded as a chain of left-child and right-sibling links.
This keeps nodes compact (32 bytes) and simplifies traversal.

See [Language Model](../language-model/index.md).

## Match Any (`--`)

The `--` operator in a pattern matches any sequence of nodes (zero or more). It
captures the matched tail for later substitution. Long match any (`---`) extends
this with additional semantics. Infix `--` in patterns can use backtracking
(enabled by `--backtracking`).

See [Match Any Captures](../transformations/patterns/match-any-captures.md).

## Meta Compute

Targeted compute behavior introduced with the `~` operator. The tilde flag forces
arithmetic reduction on a specific node or subtree even outside a backtick compute
scope.

See [Meta Compute Operator](../compute/meta-compute-operator.md).

## Meta Flags

Prefixes that modify how the runtime treats a node during evaluation, matching,
or rewriting: `~` (meta-compute), `\` (fixed), `$` (state-selection), `^` (full-match),
`.` (matching rule), `@` (at-index). Each flag is written before the target node
or subtree.

See [Meta Flags](../syntax/meta-flags.md).

## Node

The fundamental runtime unit — a typed AST element that represents a value,
operator, scope delimiter, or structural construct. Nodes are stored as compact
32-byte `TTreeNode` records in a pooled array rather than as heap-allocated
objects. Each node has a type ID that maps to a behavior class via the VMT
dispatch table.

## Node Pool

The memory management system (`TCustomTree`) that allocates nodes from a fixed
array with free-list recycling. `AllocateNode` acquires a node (from the pool
or free-list); `DisposeNode` returns it. This avoids repeated heap allocation
and keeps the runtime cache-friendly.

## Package

A reusable library of rules, callables, and definitions. Declared with the
`package` keyword and imported with `import`. Packages live under
`packages/` and provide modular, shareable Mantra code.

See [Keywords and Declarations](../syntax/keywords-declarations.md).

## Pattern Capture

Variables in a selection rule that bind matched nodes. **Lowercase** symbols
(match e.g. `x`, `y`) capture single identifiers. **Uppercase** symbols
(match e.g. `A`, `X`) capture any node regardless of type. Captured values are
substituted into the replacement template.

See [Variable Captures](../transformations/patterns/variable-captures.md).

## Pattern Matching

The process of comparing a source tree against a rule's pattern. The matcher
(`matcher_ir.pas`) traverses both trees simultaneously, binding captures and
checking structural compatibility. Rules with guards evaluate conditions after
a structural match succeeds.

See [Selection Rewrite Model](../language-model/rewriting-transformation-model/selection-rewrite-model.md).

## Repeat Operation

The transformation performed by the colon operator (`:`), where a right-hand
expression drives expansion of a left-hand pattern. An integer `n` on the right
clones the left side `n` times; `...` triggers recursive fixpoint iteration; a
variable is resolved from the context.

See [Repeat Operator](../transformations/repeat-operator/bounded-repeat.md).

## Range (`..`)

The `..` operator creates a numeric range. In compute scope, it evaluates to
a sequence of integers from left to right (e.g., `1..5` produces `1 2 3 4 5`).
Used for generating sequences and indexing operations.

## Runtime

The Mantra executable built from the Free Pascal source files in this repository.
The runtime follows the pipeline: tokenizer → parser → node registration →
evaluation → formatter → output. It supports file input, standard input, and
interactive REPL mode.

See [Building the Runtime](../getting-started/building-the-runtime.md).

## Rule (Named)

A named rewrite pattern declared with the `rule` keyword. Named rules can be
referenced by name in selection queries and inference searches, and they
preserve their names in witness traces. Inline rules (`=>`) are anonymous and
appear directly inside rule sets.

See [Rule Declaration Syntax](../syntax/operators-special-forms/rule-declaration-syntax.md).

## Scope Node

A delimited region of source that creates a specific AST node type. The five
scope delimiters are: parentheses `( ... )` (expression grouping), square
brackets `[ ... ]` (array/list), curly braces `{ ... }` (evaluation), backticks
`` ` ... ` `` (compute), and single quotes `' ... '` (fixed/no evaluation).

See [Scope Nodes](../language-model/programs-as-trees/scope-nodes.md).

## Selector (Selection Strategy)

A policy wrapper that controls which rewrite rule the selection engine applies
first or how it ranks candidates. Declared with the `selector` keyword. Selection
strategies determine match order in multi-rule sets.

See [Selection Strategies](../transformations/selection.md).

## Selection

Rule-driven rewrite behavior requested with `?` or state-selection forms such
as `$?`. The `?` operator applies the first matching rule from a rule set to a
subject tree, rewriting the matched structure. Selection supports pattern
captures, guards, and multiple matching modes (root-only, subexpression,
iterative state-selection).

See [Selection Operator](../transformations/selection/selection-operator.md).

## Selection Rewrite

The rewrite process triggered by `LHS ? RULES`. The engine evaluates the rule
set, probes each rule against the subject tree, and replaces the first successful
match with the rule's replacement template. Lowercase symbols match identifiers;
uppercase symbols match any node; `--` matches any tail sequence.

See [Selection Rewrite Model](../language-model/rewriting-transformation-model/selection-rewrite-model.md).

## State Selection (`$`)

Iterative rewrite mode enabled by the `$` meta flag. In state-selection mode,
rules are applied repeatedly to the same tree until no more matches occur,
bounded by `MAX_FIXPOINT_STEPS` (1024). Useful for global transformations
that need multiple passes.

See [State Selection](../transformations/selection/state-selection.md).

## Token

The atomic unit produced by the tokenizer (`exp_tokenizer.pas`). Token IDs are
bit-packed with category, type, operator, and meta flags. Key categories include
`TK_IDENTIFIER` (variables, literals, keywords), `TK_SPECIAL` (operators like
`:`, `?`, `=>`), `TK_SCOPE` (`()`, `[]`, `{}`, `` ` ``), `TK_OPERATOR` (arithmetic,
boolean), and `TK_META` (`~`, `\`, `$`, `^`, `@`, `.`).

See [Tokens and Whitespace](../syntax/tokens-whitespace.md).

## Transform Rule

A rule that maps a matched source pattern to a replacement tree, commonly using
`=>` (forward), `=>>` (inline), `==>` (substitution), `==>>` (inline substitution),
or `<=>` (bidirectional/equivalence). Transform rules are the core mechanism for
structural rewriting in Mantra.

See [Transform Rules](../transformations/transform-rules.md).

## Tree Expansion

The in-place mutation of the AST during evaluation. Nodes are replaced by their
first child (`Expand`), inlined at the root (`ExpandInline`), deleted, or cloned.
Tree expansion is the primary mechanism by which the runtime reduces and
transforms programs — the source tree evolves rather than being interpreted
sequentially.

## Tree Value

The runtime representation of a node's content — combining the node's type,
value (from token storage), and structural edges. When printed with `--raw`,
the unformatted `TreeValue` output shows the internal representation.

## VMT Dispatch

The behavior dispatch mechanism used by Mantra. Instead of heap-allocated
objects, nodes are compact records. A centralized `VMT_TABLE` maps each node
type ID to a class virtual method table. `GetNode` creates a lightweight stack
wrapper with the correct VMT pointer, and trampolines (`DispatchExecute`,
`DispatchEvaluate`, etc.) invoke the virtual method. This keeps evaluation
cache-friendly and allocation-free.

See [Language Model](../language-model/index.md).

## Variable

A named binding that stores a tree snapshot. Variables are assigned with `=`
(deep clone without evaluation) or `:=` (deep assignment with evaluation).
Referencing a variable substitutes a clone of the bound tree into the current
expression. Variables support structural access: `lhs x`, `rhs x`, and `all x`
extract the left child, right sibling, or full chain respectively.

See [Values, Nodes, and Expressions](../language-model/values-nodes-expressions.md).

## Witness

Proof-oriented runtime data produced by witness inference queries such as
`?|=`. Witnesses record the step-by-step rewrite path taken during inference,
including which rules applied, their orientation, and the intermediate tree
states. Witnesses are stored in the context under generated keys (`witness.w1`,
`witness.w2`, etc.) and can be inspected for detailed trace information.

See [Witnesses](../transformations/inference/witnesses.md).