# Tokens and Whitespace

Mantra source code is first **tokenized** into a stream of tokens, then **parsed**
into an abstract syntax tree. Every token carries an ID, a textual value, and a
source location (line and column). The tokenizer is a state machine defined in
`exp_tokenizer.pas`, configured by transition rules in `mathparser.pas`.

This page covers the token data structure, the tokenizer architecture, how
whitespace and comments are handled, and how tokens are stored and referenced.

For the specific tokens that create scope nodes, see [Delimiters and Scope
Tokens](tokens-whitespace/delimiters-scope-tokens.md). For operators, see
[Operator Tokens](tokens-whitespace/operator-tokens.md).

## Token Data Structure

Each token is a `TTokenInfo` packed record:

| Field | Type | Description |
|---|---|---|
| `ID` | `Cardinal` | Token type identifier (e.g. `TK_INTEGER`, `TK_PLUS`) |
| `Index` | `Integer` | Index into the shared string interning pool (`TLKStringList`) |
| `Line` | `Integer` | Source line number (1-indexed) |
| `Col` | `Integer` | Source column number (1-indexed) |

The textual value of a token is not stored directly in the record. Instead,
`Index` points into a de-duplicated string pool (`TLKStringList`). Every time
the tokenizer emits a token, it calls `Add(Value)` on the pool: if the text
already exists, the existing index is returned; otherwise a new entry is created.
This means the same literal (e.g. the variable name `x` appearing 500 times)
occupies memory only once.

An empty/terminator token has `ID = 0` and `Index = -1`.

## Tokenizer Architecture

The tokenizer is a **deterministic state machine**. It consists of:

1. **States** — `TState` records, each with a 256-entry transition table
   (`Transitions[AnsiChar]: Integer`). States are identified by integer IDs.
2. **Transitions** — rules that say "from state X on character C, go to state Y."
   Negative state IDs are intermediate; positive IDs are terminal (token types).
3. **The scanner** — iterates over input characters, follows transitions, and
   emits tokens when a terminal state is reached.

Transitions are registered in `TExpressionTokenizer.RegisterTokens` (mathparser.pas).
The API is:

```
AddTransition('char', DestinationToken)
AddTransition('char', SourceState, DestinationState)
AddTransition(['a'..'z'], DestinationToken)
AddTransition(['a'..'z'], SourceState, DestinationState)
AddTransition('sequence', DestinationToken)
```

Each call wires up one or more characters to advance the scanner from one state
to the next. Multi-character sequences (e.g. `//`, `/*`, `=>`) are split into
a chain of single-character transitions through auto-generated intermediate states.

### Backtracking on dead ends

When the scanner reaches a state with no transition (`S1 = 0`), it backtracks
through previously recorded states (`S[I-1]`, `S[I-2]`, ...) looking for the
longest valid token. This longest-match behavior means multi-character operators
like `<==>` are tokenized correctly even when shorter prefixes like `<=` also
exist.

### Case-insensitive identifiers

The tokenizer is created with `Options := [toCaseInsensitive]`. When a transition
uses a character set containing letters, both upper and lower case variants are
automatically registered. This means `x`, `X`, `MyVar`, and `MYVAR` all match
the `TK_IDENTIFIER` transition.

## Token Stream

Tokens are stored in a `TCustomExpression` — a dynamic array of `TTokenInfo`
records with a current position pointer. The expression provides navigation and
matching methods:

| Method | Description |
|---|---|
| `NextToken` | Advance cursor, return next `PTokenInfo` |
| `LastToken` | Return previous `PTokenInfo` |
| `CurToken` | Return current `PTokenInfo` (no advance) |
| `Accept(ID, Mask)` | If current token matches `ID` (under `Mask`), consume and return index |
| `AcceptMask(Mask)` | If current token matches any bit in `Mask`, consume and return index |
| `Expect(ID, Mask)` | Like `Accept` but raises an exception on mismatch |
| `TokenValue(I)` | Resolve token at index `I` back to its string value |
| `TokenFromID(ID)` | Reverse lookup: token ID to its source text |

The parser uses `Accept` and `Expect` to consume the token stream sequentially,
building the AST as it goes.

## The Ignore Mask

Tokens are categorized by type. The tokenizer has an `IgnoreMask: Cardinal`
property that determines which token types are consumed silently during
tokenization — they are recognized and skipped but never added to the output
stream. The default ignore mask includes:

```pascal
IgnoreMask := TK_SPACE or TK_TAB or TK_LINECOMMENT or
              TK_BLOCKCOMMENT or TK_NEWLINE or TK_CR;
```

This means space, tab, comments, newline, and carriage return tokens are all
filtered out before the parser sees them. The parser receives only meaningful
tokens — operators, identifiers, delimiters, literals, etc.

## Whitespace

Whitespace separates tokens. The tokenizer recognizes the following whitespace
characters:

| Character | Token ID | Hex |
|---|---|---|
| ` ` (space) | `TK_SPACE` (1) | `#32` |
| `\t` (tab) | `TK_TAB` (2) | `#9` |
| `\n` (newline) | `TK_NEWLINE` (5) | `#10` |
| `\r` (carriage return) | `TK_CR` (6) | `#13` |

All four are part of the **ignore mask** — they are consumed during tokenization
but do not appear in the token stream passed to the parser. The exact amount and
type of whitespace between two tokens is irrelevant to parsing.

For user-facing examples, prefer spacing that makes tree structure easy to read:

```mantra
[ { 1 2 3 : 4 } ]
```

Mantra is whitespace-delimited: spaces (or newlines) are the only thing that
separates adjacent tokens. `1 2` is two tokens (`1` and `2`), while `12` is a
single integer token. Similarly, `a` and `b` are separate identifiers, but
`ab` is one identifier.

## Comments

Mantra supports two comment styles. Both are part of the ignore mask and produce
no tokens.

### Line Comments

A `//` sequence begins a line comment that extends to the end of the line:

```mantra
// this is a single-line comment
` + 1 2 `   // inline comment
```

The tokenizer transitions to `TK_LINECOMMENT` on `//` and then loops on all
characters except newline (`#0..#255 - [#10]`) staying in the same state. Only
a newline terminates the line comment and returns to the initial state.

### Block Comments

A `/* ... */` pair encloses a block comment that may span multiple lines:

```mantra
/* this is a
   multi-line block comment */
` + 1 2 `
```

Block comments use a two-state machine:

1. **`TK_PARTIAL_BLOCKCOMMENT`** — the default state inside the comment.
   Any character except `*` keeps the scanner in this state. A `*` advances to
   the next state.
2. **`TK_STAR_IN_BLOCKCOMMENT`** — reached after seeing a `*`. If the next
   character is `/`, the comment ends (`TK_BLOCKCOMMENT`). Any other character
   returns to `TK_PARTIAL_BLOCKCOMMENT`.

This means a bare `*` or bare `/` does not end the comment — only the exact
sequence `*/` terminates it.

## Source Location Tracking

Every token records its `Line` and `Col` (1-indexed) from the source file.
The scanner uses a cached position resolver (`ResolveLineCol`) that counts
newlines from the last known position, avoiding rescanning from the start of
the file for every token. This makes line/column resolution efficient even for
large files.

The `--show-tokens` CLI flag prints the token stream with source locations,
useful for debugging tokenization issues:

```bash
mantra --show-tokens program.m
```

## Token Categories

Token IDs use bit fields to encode category, operator type, and metadata:

```
[31..24] META  |  [23..16] RESERVED  |  [15..8] OPERATOR  |  [7..0] ID
```

Key category masks:

| Category | Mask | Token IDs |
|---|---|---|
| Identifiers | `TK_IDENTIFIER` ($0040) | Variables, integers, strings, keywords |
| Special | `TK_SPECIAL` ($0080) | `:`, `?`, `=>`, `:=`, `,`, `.` |
| Scope | `TK_SCOPE` ($00C0) | `()`, `[]`, `{}`, `` ` ``, `'` |
| Operator | `TK_OPERATOR` ($00010000) | Arithmetic, relational, boolean |
| Meta | `TK_META` ($01000000) | `~`, `\`, `$`, `^`, `@`, `.` |

The `Accept` and `Expect` methods on the token stream use these masks to match
tokens. For example, `Accept(TK_PLUS, TK_OPERATOR_MASK)` matches `TK_PLUS`
while ignoring bits outside the operator range.

## Related Pages

- [Delimiters and Scope Tokens](tokens-whitespace/delimiters-scope-tokens.md) — scope token details
- [Operator Tokens](tokens-whitespace/operator-tokens.md) — operator token reference
- [Values and Literals](values-literals.md) — integers, floats, strings, booleans
- [Meta Flags](meta-flags.md) — `~`, `\`, `$`, `^`, `.`, `@`
- [Syntax Index](index.md) — full syntax overview
