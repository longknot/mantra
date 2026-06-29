# Third-Party Notices

Mantra source files are licensed under the Mozilla Public License 2.0 unless a
file or directory states otherwise.

This repository includes vendored third-party source code. Those dependencies
remain under their own licenses.

## Free Pascal Compiler And Runtime Libraries

Mantra is written in Free Pascal and is built with the Free Pascal Compiler.

The Free Pascal compiler is licensed under the GNU General Public License,
version 2. The Free Pascal runtime libraries and packages are distributed under
the Library GNU General Public License with the standard Free Pascal linking
exception.

The linking exception permits linking independent modules with the Free Pascal
runtime libraries and distributing the resulting executable under terms chosen
by the distributor, provided the license terms for each linked independent
module are also satisfied.

See the Free Pascal project for the complete compiler and runtime library
license texts.

## `vendor/mcp`

`vendor/mcp` contains a vendored Free Pascal implementation of the Model
Context Protocol used by `mantra_mcp_server`.

The vendored MCP library states in `vendor/mcp/README.md`:

> This code is licensed with the usual FPC LGPL with linking exception license.

The accompanying `vendor/mcp/LICENSE` file contains the Free Pascal library
license text, including the linking exception, and the GPL version 2 text for
the Free Pascal compiler.

The MCP source code remains under its own license. Mantra's MPL-2.0 license
does not relicense this vendored dependency.

## `vendor/mantra-trie`

`vendor/mantra-trie` contains vendored trie-related Free Pascal source used by
Mantra.

If this dependency is retained in the public alpha repository, its exact
upstream origin and license should be confirmed and documented before a
non-alpha release. For the alpha release, do not remove or alter any upstream
license notices present in the vendored files.

