# Statement Execution

Statements are the top-level unit of execution in Mantra. A source program consists
of one or more statements separated by semicolons. Statements are executed
sequentially from first to last, sharing a single `TContext` that carries
variables, rules, packages, and other runtime state.

## Syntax

```mantra
statement1;
statement2;
statement3;
```

Each statement is parsed as a standalone expression tree wrapped in a
`TStatementNode`. The semicolon is the delimiter between statements, not part of
the statement itself. The last statement in a program may omit the trailing
semicolon.

## Parsing

The parser (`mathparser.pas`) processes statements in the `Parse` method of
`TExpressionTree`. For each statement it encounters:

1. Calls `AddStatement` to allocate a new node and append it to the
   `FStatements` array.
2. Initializes the node as `OBJ_STATEMENT` via `TStatementNode.InitTreeNode`.
3. Stores the current source token reference in `Node[Stmt]^.Ref`.
4. Calls `ParseExpression` to build the expression subtree as the statement's
   child (LHS).
5. If tokens remain, expects a semicolon (`TK_SEMICOLON`) before parsing the
   next statement.

The `FStatements` array — accessible as the `Statements` property — holds the
tree indices of all statement roots in source order.

## Execution Loop

The runtime iterates over statements in `TExecutable.Execute`. For each statement:

1. **Retrieve the statement node** from `ExecQueue[StmtIndex]`. The queue is
   initialized from `Tree.Statements`.
2. **Emit debug input** (if `--debug` / `RunOptions.ShowInput` is set): prints
   `> <statement_tree_value>` before execution.
3. **Notify the debugger** (if attached): emits a `dekStatementEnter` event with
   source location, then pauses if breakpoints are hit.
4. **Execute the statement**: calls `Node.Execute(AContext)` on the `TStatementNode`.
   The `TStatementNode.Execute` method dispatches to its child nodes, which
   evaluate the expression.
5. **Emit debug output** (if `--debug` / `RunOptions.DebugOutput` is set and the
   statement is not an output node): prints the formatted result of the
   statement's tree after evaluation. In `--raw` mode, the unformatted
   `TreeValue` is printed instead.
6. **Handle dynamic statements**: if new statements were added during execution
   (e.g., by `include` or `import`), they are inserted into the execution queue
   immediately after the current statement.
7. **Debugger exit event**: emits `dekStatementExit` and pauses if needed.
8. **Advance** to the next statement.

The loop continues until all statements in the queue have been processed.

### Dynamic Statement Insertion

Some statements — such as `include`, `import`, or `package` declarations — can
add new statements to the tree during execution. The runtime detects this by
comparing `Length(Tree.Statements)` before and after execution. If new statements
were added, they are spliced into `ExecQueue` immediately after the current
position, so they execute before the original statements that follow.

```mantra
x = 1;
include "extra.m";   ! statements from extra.m run here
print { x };
```

## Shared Context

All statements share a single `TContext` instance. This means:

- Variables assigned in one statement are visible in all subsequent statements.
- Rules defined with `rule` are available to later rewrite operations.
- Packages imported with `import` or `include` extend the shared namespace.
- Callable declarations persist across all statements.

```mantra
x = [ 1 2 3 ];
y = [ 4 5 6 ];
print { x y };    ! both variables are available
```

## Output Behavior

Statements produce output through explicit output nodes (`print`, `output`,
`tree`, `ir`). When a statement's first child is one of these output node types,
the runtime suppresses its automatic debug output for that statement — the
output node itself is responsible for emitting results.

Non-output statements produce output only when `--debug` or `--debug-ir` flags
are active.

## Dispatch Lifecycle

Each statement node is a `TStatementNode` whose child (LHS) holds the parsed
expression. When `Node.Execute(AContext)` is called on a `TStatementNode`:

1. `TStatementNode.Execute` calls `inherited Execute(Context)` (i.e.,
   `TBaseNode.Execute`).
2. `TBaseNode.Execute` calls `Dispatch(@TBaseNode.DispatchExecute, Context)`.
3. `Dispatch` recursively walks LHS and RHS children, invoking `Execute` on
   each node through the VMT dispatch table.
4. Each node type implements its own `Execute` method defining what happens
   during the execution phase — e.g., `TAssignmentNode` stores values,
   `TPrintNode` formats and emits output, etc.

The full dispatch lifecycle is:

```
Execute    — recursive execution over children (evaluates assignments,
              calls callables, resolves variables)
  └── Evaluate  — fixed/unfix gating, evaluate descendants,
                   run DoEvaluate, trigger Compute if ~, collapse { }
    └── Compute  — arithmetic reduction in ` ` scope
    └── Expand   — tree expansion (repeat, transform)
    └── Transform — rule-based rewriting
    └── Complete — cleanup (ClearRewrite, ClearEvaluation)
```

The `Execute` phase comes before `Evaluate` and handles control-flow operations
(assignments, definitions, output).

## TStatementNode Details

`TStatementNode` is a minimal wrapper. Its implementation:

- **Execute**: calls `inherited Execute(Context)` — dispatches to children.
- **TokenValue**: returns the formatted value of its LHS child, or empty string
  if the statement has no child. The semicolon itself is not included in the
  output.

The statement node does not transform or evaluate its content during the
`Execute` phase — it simply provides a tree boundary between sequential
statements. The expression inside the statement is evaluated through the normal
dispatch chain (Execute → Evaluate → Compute).

## Examples

### Multi-statement variable dependency

```mantra
x = [ + 1 2 3 ];
print { x };
```

Output: `+ 6`

The assignment runs before the print. The `print` statement reads the variable
`x` stored in the shared context.

### Statement-level package import

```mantra
import "math";
x = [ + 1 2 3 ];
print { x };
```

The `import` statement loads the package and may add new statements (definitions,
rules) to the execution queue. Those statements run immediately after the import
and before the following statements.

### Multiple assignments in sequence

```mantra
a = 10;
b = 20;
c = [ + { a } { b } ];
print { c };
```

Output: `+ 30`

Each assignment updates the shared context. Later statements see all previous
assignments.

### Empty trailing statement

```mantra
x = 5;
```

A single statement without a trailing semicolon is valid. The parser treats the
end of input as an implicit statement boundary.

## Debug Output

The `--debug` flag (`RunOptions.DebugOutput`) controls per-statement output:

- **Before execution**: prints `> <statement>` showing the input tree value.
- **After execution**: prints the evaluated result for non-output statements.
- **`--raw` mode**: prints the unformatted `TreeValue` instead of the
  formatted tree.
- **`--debug-ir` mode**: prints the intermediate representation using
  `TIRFormatter`.

Output statements (`print`, `output`, `tree`, `ir`) suppress automatic debug
output — only their own output node emits results.

## Related Pages

- [Head Dispatch](head-dispatch.md) — callable dispatch from head position
- [Evaluation Scopes](../evaluation-scopes.md) — curly brace, backtick, and fixed scopes
- [Print Output](../evaluation-scopes/print-output.md) — explicit output nodes
- [Variables and Bindings](../data/variables-bindings.md) — shared variable context
