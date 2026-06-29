# Shell Quoting

Shell quoting matters because Mantra uses backticks for compute scope, while
most shells use backticks for command substitution. If the shell intercepts
the backticks before Mantra receives the source, the program will fail or
produce unexpected results.

## The Problem

Backticks (`` ` ``) are the Mantra compute scope delimiter. In bash, zsh, and
other POSIX-compatible shells, backticks trigger command substitution — the
shell executes the content between backticks as a command and replaces it with
the command's output.

```bash
# This looks like valid Mantra...
echo "`[ + 1 2 3 ] : 3`" | ./bin/mantra

# ...but the shell runs `[ + 1 2 3 ] : 3` as a shell command first.
# Mantra never sees the backticks.
```

The shell tries to execute `[ + 1 2 3 ] : 3` as a command, which either fails
with a "command not found" error or produces unexpected output that Mantra then
receives as garbled input.

## The Solution: Single Quotes

Always wrap Mantra programs containing backticks in **single quotes**. Single
quotes prevent all shell interpretation — no variable expansion, no command
substitution, no escape sequences.

```bash
echo '`[ + 1 2 3 ] : 3`' | ./bin/mantra
```

Expected output:

```text
[ + 6 ] [ + 6 ] [ + 6 ]
```

The single quotes ensure Mantra receives the exact characters `` `[ + 1 2 3 ] : 3` ``
as written, including the backticks.

## What Not to Do

### Double quotes

Double quotes allow command substitution via backticks. The shell will
interpret the backtick content before passing it to Mantra.

```bash
# Incorrect — shell interprets backticks
echo "`[ + 1 2 3 ] : 3`" | ./bin/mantra
```

### No quotes at all

Without any quoting, the shell tokenizes the program on spaces and special
characters, breaking it into separate arguments before Mantra sees it.

```bash
# Incorrect — shell breaks the program into separate tokens
echo `[ + 1 2 3 ] : 3` | ./bin/mantra
```

### Dollar-sign backticks

Some shells support `` $(...) `` as an alternative command substitution syntax.
While this avoids backtick conflicts, it introduces its own quoting issues
and is not portable across all shells.

## Other Shell Special Characters

Mantra programs may contain characters that are special to the shell beyond
backticks. Single quotes protect against all of these:

| Character | Shell Meaning | Example in Mantra |
|---|---|---|
| `` ` `` | Command substitution | `` ` + 1 2 ` `` |
| `$` | Variable expansion | `$x`, `${name}` |
| `!` | History expansion (bash) | `[ ! a b ]` |
| `*` | Glob expansion | pattern matching |
| `?` | Glob / selection | `[ a ] ? [ x => x + 1 ]` |
| `\|` | Pipe | (rare in Mantra source) |
| `&` | Background / concatenation | `&` for concatenation |
| `;` | Command separator | (rare in Mantra source) |
| `<` / `>` | Redirection | (rare in Mantra source) |

Single quotes neutralize all of these. The only character that cannot appear
inside single quotes is a single quote itself.

## Heredocs for Multi-line Programs

For programs spanning multiple lines, use a heredoc with a **single-quoted
delimiter** to prevent shell expansion:

```bash
./bin/mantra <<'EOF'
x = [ 1 2 3 ]
`[ + 1 2 3 ]`
x ? [ y => y + 1 ]
EOF
```

The single quotes around `'EOF'` are critical — they tell the shell not to
expand variables or interpret backticks inside the heredoc body. Without them,
the heredoc would still process backticks as command substitution.

```bash
# Incorrect — shell expands backticks inside the heredoc
./bin/mantra <<EOF
`[ + 1 2 3 ]`
EOF

# Correct — single-quoted delimiter prevents expansion
./bin/mantra <<'EOF'
`[ + 1 2 3 ]`
EOF
```

## Escaping Inside Single Quotes

Single quotes cannot contain single quotes. If your Mantra program contains
a single quote (used for fixed scope `' ... '`), you have two options:

### Option 1: Close and reopen with an escaped quote

```bash
echo 'program part '\''fixed scope'\'' rest' | ./bin/mantra
```

This breaks the single-quoted string, inserts a literal single quote
(`\'`), then resumes the single-quoted string.

### Option 2: Use a heredoc

```bash
./bin/mantra <<'EOF'
' + 1 2 '
EOF
```

Heredocs with single-quoted delimiters can contain single quotes without
any escaping needed.

### Option 3: Use dollar-sign quoting (bash/zsh)

```bash
echo $'program with \'fixed scope\' part' | ./bin/mantra
```

The `$'...'` syntax allows backslash escapes inside, including `\'` for
literal single quotes.

## Shell-Specific Notes

### Bash

- Backticks trigger command substitution (use `$()` as modern alternative,
  though this doesn't help with Mantra since backticks are the language
  delimiter, not the shell's).
- Single quotes prevent all expansion.
- `$'...'` ANSI-C quoting is available for escaping single quotes.
- `set -H` / `set +H` controls history expansion with `!`, but single quotes
  already block it.

### Zsh

- Similar to bash for single/double quote behavior.
- By default, zsh allows nested single quotes in some contexts, but relying
  on this reduces portability. Stick to the standard single-quote behavior
  shown above.

### Fish

- Fish does not use backticks for command substitution (it uses `(...)`),
  so the backtick conflict is less severe.
- However, fish still treats `$`, `*`, `?`, `&`, and other characters as
  special. Single quotes are still the safest approach.
- Fish's single quotes work the same way as bash — no escaping possible
  inside them.

### Windows PowerShell

- PowerShell uses backticks for line continuation and escape sequences, not
  command substitution.
- Use single quotes for literal strings: `echo '` + 1 2 `'` works.
- However, PowerShell's single quotes still cannot contain literal single
  quotes. Use here-strings for complex cases:

```powershell
@'
` + 1 2 3 `
'@ | .\bin\mantra.exe
```

## Practical Examples

### Simple compute expression

```bash
echo '` + 1 2 3 `' | ./bin/mantra
```

Output: `+ 6`

### Nested compute scopes

```bash
echo '[ ` + 1 2 ` ` + 3 4 ` ]' | ./bin/mantra
```

Output: `[ + 3 + 7 ]`

### Compute with repeat

```bash
echo '`[ + 1 2 3 ] : 3`' | ./bin/mantra
```

Output: `[ + 6 ] [ + 6 ] [ + 6 ]`

### Deeply nested compute and evaluation scopes

```bash
echo '{ [ `+ 1 + 2 + 3` : 2 ] : 3 }' | ./bin/mantra
```

Output: `[ + 6 + 6 ] [ + 6 + 6 ] [ + 6 + 6 ]`

### Selection with backticks

```bash
echo '[ 1 2 3 ] ? [ x => ` + x 1` ]' | ./bin/mantra
```

### Multi-statement program with heredoc

```bash
./bin/mantra <<'EOF'
x = 10
y = ` + x 5 `
` * y 2 `
EOF
```

## Common Errors and How to Recognize Them

### "command not found" error

```bash
$ echo "`[ + 1 2 3 ] : 3`" | ./bin/mantra
bash: [ + 1 2 3 ] : 3: command not found
```

The shell tried to execute the content between backticks. Use single quotes
instead.

### Empty or garbled Mantra output

If the shell command substitution happens to produce something (e.g., a
variable name that the shell recognizes), Mantra receives unexpected input
and may produce confusing output or errors.

### Unexpected variable expansion

```bash
$ echo "` + $x 2 `" | ./bin/mantra
```

Both the backticks (command substitution) and `$x` (variable expansion)
are processed by the shell. Use single quotes to protect both.

## Summary of Best Practices

1. **Always use single quotes** for one-line Mantra programs piped via
   `echo` — especially when backticks are present.
2. **Use heredocs with single-quoted delimiters** (`<<'EOF'`) for multi-line
   programs.
3. **Avoid double quotes** unless you intentionally want shell expansion.
4. **For programs with single quotes**, prefer heredocs over quote-escaping
   tricks.
5. **When writing scripts**, always test the quoting by printing the command
   first (`echo "echo '` + 1 2 `'"`) before piping to Mantra.

## See Also

- [Standard Input](standard-input.md) — Piping programs to Mantra
- [File Input](file-input.md) — Running from a file (avoids quoting issues)
- [Running Programs](../running-programs.md) — Overview of all input methods
- [Compute and Operators](../../compute/index.md) — Backtick scope semantics
