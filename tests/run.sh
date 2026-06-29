#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CASES_DIR="$ROOT_DIR/tests/cases"

BUILD=1
STRICT=0
FILTER=""
JOBS=12
JOBS_EXPLICIT=0
INTERNAL_CASE=""
HTTP_SERVER_PID=""
HTTP_PORT_FILE=""
JOBLOG=""

cleanup() {
  if [[ -n "$HTTP_SERVER_PID" ]]; then
    kill "$HTTP_SERVER_PID" >/dev/null 2>&1 || true
    wait "$HTTP_SERVER_PID" >/dev/null 2>&1 || true
  fi
  if [[ -n "$HTTP_PORT_FILE" ]]; then
    rm -f "$HTTP_PORT_FILE"
  fi
  if [[ -n "$JOBLOG" ]]; then
    rm -f "$JOBLOG"
  fi
}
trap cleanup EXIT

usage() {
  cat <<'EOF'
Usage: tests/run.sh [options]

Options:
  --no-build        Skip rebuilding mantra before tests
  --strict          Compare OUTPUT exactly (default: whitespace-normalized)
  --filter <name>   Run only cases whose file name contains <name>
  --jobs <N>        Run up to N test cases in parallel (default: 12)
  -h, --help        Show this help

Fixture files:
  <case>.in         Input passed to mantra stdin
  <case>.out        Expected raw output
  <case>.args       Optional extra CLI args (whitespace-separated)
EOF
}

normalize() {
  local value="$1"
  value="$(printf '%s' "$value" | tr -d '\r')"
  if [[ "$STRICT" -eq 0 ]]; then
    value="$(printf '%s\n' "$value" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
    value="$(printf '%s\n' "$value" | sed -E '/^[[:space:]]*$/d')"
  fi
  printf '%s' "$value"
}

ensure_http_server() {
  local attempt port

  if [[ -n "${MANTRA_TEST_HTTP_URL:-}" ]]; then
    return 0
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is required for HTTP fixtures" >&2
    return 1
  fi

  HTTP_PORT_FILE="$(mktemp)"
  python3 "$ROOT_DIR/tests/http_fixture_server.py" "$HTTP_PORT_FILE" &
  HTTP_SERVER_PID="$!"

  for attempt in $(seq 1 100); do
    if [[ -s "$HTTP_PORT_FILE" ]]; then
      port="$(cat "$HTTP_PORT_FILE")"
      export MANTRA_TEST_HTTP_URL="http://127.0.0.1:$port"
      return 0
    fi
    if ! kill -0 "$HTTP_SERVER_PID" >/dev/null 2>&1; then
      echo "HTTP fixture server exited before becoming ready" >&2
      return 1
    fi
    sleep 0.05
  done

  echo "Timed out waiting for HTTP fixture server" >&2
  return 1
}

run_case() {
  local case_name="$1"
  local in_file="$CASES_DIR/$case_name.in"
  local out_file="$CASES_DIR/$case_name.out"
  local args_file="$CASES_DIR/$case_name.args"
  local input_text expected_raw run_output actual_raw expected actual
  local case_args=()
  local case_temp_dir=""

  if [[ ! -f "$in_file" ]]; then
    echo "[fail] $case_name"
    echo "  missing input fixture: $in_file"
    return 1
  fi

  if [[ ! -f "$out_file" ]]; then
    echo "[fail] $case_name"
    echo "  missing output fixture: $out_file"
    return 1
  fi

  input_text="$(cat "$in_file")"
  expected_raw="$(cat "$out_file")"

  if [[ "$expected_raw" == *"__ROOT_DIR__"* ]]; then
    expected_raw="${expected_raw//__ROOT_DIR__/$ROOT_DIR}"
  fi

  if [[ "$input_text" == *"__TEMP_DIR__"* ]]; then
    case_temp_dir="$(mktemp -d)"
    input_text="${input_text//__TEMP_DIR__/$case_temp_dir}"
    expected_raw="${expected_raw//__TEMP_DIR__/$case_temp_dir}"
  fi

  if [[ "$input_text" == *"__HTTP_BASE__"* ]]; then
    ensure_http_server
    input_text="${input_text//__HTTP_BASE__/$MANTRA_TEST_HTTP_URL}"
    if [[ "$case_name" != "http_disabled" ]]; then
      case_args+=("--set=mantra.external.enabled=true")
    fi
    case_args+=("--set=mantra.external.http.allowed_schemes=\"http,https\"")
    if [[ "$case_name" != "http_private_network_denied" ]]; then
      case_args+=("--set=mantra.external.http.allow_private_networks=true")
    fi
  fi

  if [[ -f "$args_file" ]]; then
    while IFS= read -r arg; do
      case_args+=("$arg")
    done < <(xargs -a "$args_file" -n1 printf '%s\n')
  fi

  run_output="$(printf '%s\n' "$input_text" | "$ROOT_DIR/bin/mantra" --raw "${case_args[@]}")"
  actual_raw="$run_output"
  if [[ -n "$case_temp_dir" ]]; then
    rm -rf "$case_temp_dir"
  fi

  expected="$(normalize "$expected_raw")"
  actual="$(normalize "$actual_raw")"

  if [[ "$expected" == "$actual" ]]; then
    echo "[pass] $case_name"
    return 0
  fi

  echo "[fail] $case_name"
  echo "  input:"
  printf '%s\n' "$input_text" | sed 's/^/    /'
  echo "  expected OUTPUT line(s):"
  printf '%s\n' "$expected_raw" | sed 's/^/    /'
  echo "  actual OUTPUT line(s):"
  printf '%s\n' "$actual_raw" | sed 's/^/    /'
  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-build)
      BUILD=0
      shift
      ;;
    --strict)
      STRICT=1
      shift
      ;;
    --filter)
      FILTER="${2:-}"
      if [[ -z "$FILTER" ]]; then
        echo "Missing value for --filter" >&2
        exit 2
      fi
      shift 2
      ;;
    --jobs)
      JOBS="${2:-}"
      if [[ -z "$JOBS" ]]; then
        echo "Missing value for --jobs" >&2
        exit 2
      fi
      if ! [[ "$JOBS" =~ ^[0-9]+$ ]] || [[ "$JOBS" -lt 1 ]]; then
        echo "Invalid value for --jobs: $JOBS (expected integer >= 1)" >&2
        exit 2
      fi
      JOBS_EXPLICIT=1
      shift 2
      ;;
    --internal-case)
      INTERNAL_CASE="${2:-}"
      if [[ -z "$INTERNAL_CASE" ]]; then
        echo "Missing value for --internal-case" >&2
        exit 2
      fi
      shift 2
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

if [[ ! -d "$CASES_DIR" ]]; then
  echo "Cases directory not found: $CASES_DIR" >&2
  exit 2
fi

if [[ "$BUILD" -eq 1 ]]; then
  echo "[build] Compiling mantra..."
  (
    cd "$ROOT_DIR"
    mkdir -p bin build
    fpc mantra.lpr -FEbin -FUbuild -Fusrc -Fuvendor/* -Px86_64 -Mobjfpc -S2cahi -O1 -gw3 -v0 >/dev/null
  )
fi

if [[ -n "$INTERNAL_CASE" ]]; then
  run_case "$INTERNAL_CASE"
  exit $?
fi

selected_cases=()
for in_file in "$CASES_DIR"/*.in; do
  [[ -e "$in_file" ]] || continue

  case_name="$(basename "$in_file" .in)"
  out_file="$CASES_DIR/$case_name.out"

  if [[ ! -f "$out_file" ]]; then
    echo "[skip] $case_name (missing $out_file)"
    continue
  fi

  if [[ -n "$FILTER" && "$case_name" != *"$FILTER"* ]]; then
    continue
  fi

  selected_cases+=("$case_name")
done

total="${#selected_cases[@]}"
if [[ "$total" -eq 0 ]]; then
  echo "No test cases selected."
  exit 2
fi

failed=0
for case_name in "${selected_cases[@]}"; do
  if grep -q "__HTTP_BASE__" "$CASES_DIR/$case_name.in"; then
    ensure_http_server
    break
  fi
done

if [[ "$JOBS" -gt 1 ]] && ! command -v parallel >/dev/null 2>&1; then
  if [[ "$JOBS_EXPLICIT" -eq 1 ]]; then
    echo "GNU parallel not found. Install 'parallel' or run with --jobs 1." >&2
    exit 2
  fi
  echo "GNU parallel not found. Falling back to --jobs 1." >&2
  JOBS=1
fi

if [[ "$JOBS" -le 1 ]]; then
  for case_name in "${selected_cases[@]}"; do
    if ! run_case "$case_name"; then
      failed=$((failed + 1))
    fi
  done
else
  JOBLOG="$(mktemp)"

  if [[ "$STRICT" -eq 1 ]]; then
    if ! parallel --will-cite --jobs "$JOBS" --keep-order --joblog "$JOBLOG" \
      "$0" --no-build --strict --internal-case {} ::: "${selected_cases[@]}"; then
      :
    fi
  else
    if ! parallel --will-cite --jobs "$JOBS" --keep-order --joblog "$JOBLOG" \
      "$0" --no-build --internal-case {} ::: "${selected_cases[@]}"; then
      :
    fi
  fi

  failed="$(awk 'NR > 1 && $7 != 0 { c++ } END { print c + 0 }' "$JOBLOG")"
fi

echo
echo "Summary: $((total - failed))/$total passed"
if [[ "$failed" -ne 0 ]]; then
  exit 1
fi
