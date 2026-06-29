#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD=1

usage() {
  cat <<'EOF'
Usage: tests/server_smoke.sh [--no-build]

Runs a small stdio JSON server smoke test against bin/mantra_server.
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
    fpc mantra_server.lpr -FEbin -FUbuild -Fusrc -Fuvendor/* -Px86_64 -Mobjfpc -S2cahi -O1 -gw3 -v0 >/dev/null
  )
fi

request_output="$(
  printf '%s\n' \
    '{"id":1,"method":"exec","params":{"code":"x = + 1 2;"}}' \
    '{"id":2,"method":"eval","params":{"expr":"x"}}' \
    '{"id":3,"method":"get","params":{"path":"x"}}' \
    '{"id":4,"method":"exec","params":{"code":"printf \"hello %s\" [ \"world\" ];"}}' \
    '{"id":5,"method":"exec","params":{"code":"{ assign_path \"demo.items[1]\" \"a\" }; { assign_path \"demo.items[2]\" \"b\" };"}}' \
    '{"id":6,"method":"query_children","params":{"prefix":"demo.items"}}' \
    '{"id":7,"method":"session.reset","params":{}}' \
    '{"id":8,"method":"get","params":{"path":"x"}}' \
    '{"id":9,"method":"exec","params":{"code":"{ assign_path \"chart.mark\" \"line\" }; display \"application/vnd.vegalite.v6+json\" chart;"}}' \
    '{"id":10,"method":"shutdown","params":{}}' \
    | "$ROOT_DIR/bin/mantra_server"
)"

assert_contains() {
  local needle="$1"
  if ! grep -Fq "$needle" <<<"$request_output"; then
    echo "[fail] missing expected output: $needle" >&2
    echo "$request_output" >&2
    exit 1
  fi
}

assert_contains '"id" : 1, "ok" : true'
assert_contains '"id" : 2, "ok" : true'
assert_contains '"text" : "+ 1 2 "'
assert_contains '"id" : 3, "ok" : true'
assert_contains '"text" : "+ 1 + 2"'
assert_contains '"text" : "hello world"'
assert_contains '"items" : ["demo.items[1]", "demo.items[2]"]'
assert_contains '"id" : 7, "ok" : true'
assert_contains '"text" : "reset"'
assert_contains '"id" : 8, "ok" : false'
assert_contains '"code" : "not_found"'
assert_contains '"id" : 9, "ok" : true'
assert_contains '"mime" : "application/vnd.vegalite.v6+json"'
assert_contains '"data" : { "mark" : "line" }'
assert_contains '"id" : 10, "ok" : true'

echo "[pass] server_smoke"
