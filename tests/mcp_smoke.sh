#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD=1

usage() {
  cat <<'EOF'
Usage: tests/mcp_smoke.sh [--no-build]

Runs a small MCP stdio smoke test against bin/mantra_mcp_server.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-build)
      BUILD=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$BUILD" -eq 1 ]]; then
  (
    cd "$ROOT_DIR"
    mkdir -p bin build
    fpc mantra_mcp_server.lpr -FEbin -FUbuild -Fusrc -Fuvendor/* -Fuvendor/mcp/Src/Base -Px86_64 -Mobjfpc -S2cahi -O1 -gw3 -v0 >/dev/null
  )
fi

request_output="$(
  printf '%s\n' \
    '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"smoke","version":"0.1"}}}' \
    '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}' \
    '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
    '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"mantra_exec","arguments":{"code":"x = + 1 2;"}}}' \
    '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"mantra_eval","arguments":{"expr":"x"}}}' \
    '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"mantra_reset","arguments":{}}}' \
    '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"mantra_get","arguments":{"path":"x"}}}' \
    | "$ROOT_DIR/bin/mantra_mcp_server"
)"

assert_contains() {
  local needle="$1"
  if ! grep -Fq "$needle" <<<"$request_output"; then
    echo "[fail] missing expected output: $needle" >&2
    echo "$request_output" >&2
    exit 1
  fi
}

assert_contains '"protocolVersion" : "2025-06-18"'
assert_contains '"name" : "mantra_exec"'
assert_contains '"name" : "mantra_eval"'
assert_contains '"name" : "mantra_get"'
assert_contains '"id" : 3'
assert_contains '"text\" : \"\"'
assert_contains '"id" : 4'
assert_contains '+ 1 2'
assert_contains '"id" : 5'
assert_contains 'reset'
assert_contains '"id" : 6'
assert_contains 'not_found'

echo "[pass] mcp_smoke"
