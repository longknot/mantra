#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANTRA_BIN="${MANTRA_BIN:-$ROOT_DIR/bin/mantra}"
PACKAGE_TOOL="${PACKAGE_TOOL:-$ROOT_DIR/mantra-pkg}"
TMP_DIR=""

cleanup() {
  if [[ -n "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

fail() {
  printf 'git-pkgs PoC failed: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

init_repo() {
  local path="$1"
  local package_name="$2"

  mkdir -p "$path"
  git init -q -b main "$path"
  git -C "$path" config user.name "Mantra git-pkgs PoC"
  git -C "$path" config user.email "poc@example.invalid"
  (
    cd "$path"
    "$PACKAGE_TOOL" init "$package_name"
  )
}

require_command git
require_command jq
[[ -x "$(git --exec-path)/git-pkgs" ]] || fail "'git pkgs' is not installed"
[[ -x "$MANTRA_BIN" ]] || fail "Mantra binary not found: $MANTRA_BIN"
[[ -x "$PACKAGE_TOOL" ]] || fail "package adapter not found: $PACKAGE_TOOL"

# Avoid inheriting git-pkgs' optional debug environment setting.
unset DEBUG

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mantra-git-pkgs-poc.XXXXXX")"
BASE_REPO="$TMP_DIR/base"
HTTP_REPO="$TMP_DIR/http"
APP_REPO="$TMP_DIR/app"
REGISTRY_REPO="$TMP_DIR/http-registry.git"

printf '[1/5] Release acme/base@v0.1.0\n'
init_repo "$BASE_REPO" acme/base
cat > "$BASE_REPO/package.m" <<'EOF'
package acme/base;

value = 40;
EOF
git -C "$BASE_REPO" add package.m pkgs.json
git -C "$BASE_REPO" commit -q -m "Create acme/base"
(
  cd "$BASE_REPO"
  "$PACKAGE_TOOL" publish v0.1.0
)

printf '[2/5] Release acme/http@v0.1.0 with a transitive dependency\n'
init_repo "$HTTP_REPO" acme/http
cat > "$HTTP_REPO/package.m" <<'EOF'
package acme/http;

import acme/base;
answer = acme.base.value;
EOF
git -C "$HTTP_REPO" add package.m pkgs.json
git -C "$HTTP_REPO" commit -q -m "Create acme/http"
(
  cd "$HTTP_REPO"
  "$PACKAGE_TOOL" add acme/base v0.1.0 "$BASE_REPO"
)
git -C "$HTTP_REPO" add pkgs.json
git -C "$HTTP_REPO" commit -q -m "Depend on acme/base"

printf '[3/5] Publish the package graph to a bare Git registry\n'
git init -q --bare "$REGISTRY_REPO"
(
  cd "$HTTP_REPO"
  "$PACKAGE_TOOL" publish v0.1.0 "$REGISTRY_REPO"
)
git --git-dir="$REGISTRY_REPO" show-ref --verify --quiet \
  refs/pkgs/acme/http/v0.1.0/acme/http ||
  fail "registry is missing acme/http release ref"
git --git-dir="$REGISTRY_REPO" show-ref --verify --quiet \
  refs/pkgs/acme/http/v0.1.0/acme/base ||
  fail "registry is missing transitive acme/base ref"

printf '[4/5] Add acme/http to a fresh application\n'
init_repo "$APP_REPO" demo/app
cat > "$APP_REPO/main.m" <<'EOF'
package main;
import acme/http;
print { acme.http.answer };
EOF
git -C "$APP_REPO" add main.m pkgs.json
git -C "$APP_REPO" commit -q -m "Create demo application"
(
  cd "$APP_REPO"
  if "$PACKAGE_TOOL" add acme/http HEAD "$REGISTRY_REPO" >/dev/null 2>&1; then
    fail "adapter accepted mutable HEAD dependency"
  fi
  "$PACKAGE_TOOL" add acme/http v0.1.0 "$REGISTRY_REPO"
)

jq -e '.dependencies["acme/http"] == "v0.1.0"' \
  "$APP_REPO/pkgs.json" >/dev/null ||
  fail "application manifest does not contain acme/http@v0.1.0"
[[ -f "$APP_REPO/.mantra/package/acme/http/package.m" ]] ||
  fail "acme/http was not materialized"
[[ -f "$APP_REPO/.mantra/package/acme/base/package.m" ]] ||
  fail "acme/base was not materialized"
[[ "$(git -C "$APP_REPO" status --short)" == " M pkgs.json" ]] ||
  fail "dependency worktrees leaked into application Git status"
grep -Fqx '/.mantra/package/' "$APP_REPO/.git/info/exclude" ||
  fail "package root was not added to the local Git exclude file"

TREE_OUTPUT="$(
  cd "$APP_REPO"
  "$PACKAGE_TOOL" tree | sed $'s/\033\\[[0-9;]*m//g'
)"
grep -q 'acme/http.*v0.1.0' <<< "$TREE_OUTPUT" ||
  fail "dependency tree does not contain acme/http@v0.1.0"
grep -q 'acme/base.*v0.1.0' <<< "$TREE_OUTPUT" ||
  fail "dependency tree does not contain acme/base@v0.1.0"

printf '[5/5] Load the materialized packages with Mantra\n'
RUN_OUTPUT="$(
  "$MANTRA_BIN" \
    --raw \
    --package-root "$APP_REPO/.mantra/package" \
    "$APP_REPO/main.m"
)"
[[ "$RUN_OUTPUT" == "40" ]] ||
  fail "expected Mantra output 40, got: $RUN_OUTPUT"

git -C "$APP_REPO" worktree remove -f \
  "$APP_REPO/.mantra/package/acme/http"
git -C "$APP_REPO" worktree remove -f \
  "$APP_REPO/.mantra/package/acme/base"
git -C "$APP_REPO" worktree prune
(
  cd "$APP_REPO"
  "$PACKAGE_TOOL" sync >/dev/null
)
[[ -f "$APP_REPO/.mantra/package/acme/http/package.m" ]] ||
  fail "checkout HEAD did not rehydrate acme/http"
[[ -f "$APP_REPO/.mantra/package/acme/base/package.m" ]] ||
  fail "checkout HEAD did not rehydrate acme/base"

printf '\nDependency tree:\n%s\n' "$TREE_OUTPUT"
printf '\n[pass] git-pkgs publish, add, tree, checkout, and Mantra loading\n'
