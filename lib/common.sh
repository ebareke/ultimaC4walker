# shellcheck shell=bash
# ---------------------------------------------------------------------------
# lib/common.sh — shared helpers for ultimaC4walker
#
# Logging, command execution (dry-run aware), tool discovery, and a small
# injection-safe YAML reader. Sourced by bin/c4walker and the other lib/*.sh
# modules. Written to run on bash 3.2+ (no associative arrays).
# ---------------------------------------------------------------------------

# Colours only on a TTY (and never under C4_NO_COLOR).
if [ -t 2 ] && [ -z "${C4_NO_COLOR:-}" ]; then
  C4_RED=$'\033[31m'; C4_YEL=$'\033[33m'; C4_GRN=$'\033[32m'
  C4_BLU=$'\033[34m'; C4_DIM=$'\033[2m'; C4_RST=$'\033[0m'
else
  C4_RED=''; C4_YEL=''; C4_GRN=''; C4_BLU=''; C4_DIM=''; C4_RST=''
fi

log_info() { printf '%s[INFO]%s %s\n'  "$C4_BLU" "$C4_RST" "$*" >&2; }
log_ok()   { printf '%s[ OK ]%s %s\n'  "$C4_GRN" "$C4_RST" "$*" >&2; }
log_warn() { printf '%s[WARN]%s %s\n'  "$C4_YEL" "$C4_RST" "$*" >&2; }
log_err()  { printf '%s[FAIL]%s %s\n'  "$C4_RED" "$C4_RST" "$*" >&2; }
die()      { log_err "$*"; exit 1; }

# run_cmd "command string" — execute, or just print under --dry-run.
# DRYRUN is exported by the CLI (1 = dry run, 0 = execute).
run_cmd() {
  local cmd="$1"
  if [ "${DRYRUN:-0}" -eq 1 ]; then
    printf '%s[DRY]%s %s\n' "$C4_DIM" "$C4_RST" "$cmd" >&2
  else
    printf '%s[RUN]%s %s\n' "$C4_DIM" "$C4_RST" "$cmd" >&2
    eval "$cmd"
  fi
}

# require_tool "display-name" "binary" — fail unless binary is on PATH.
# Skipped under --dry-run so the orchestration can be exercised tool-free.
require_tool() {
  local name="$1" bin="${2:-$1}"
  if [ "${DRYRUN:-0}" -eq 1 ]; then return 0; fi
  command -v "$bin" >/dev/null 2>&1 \
    || die "required tool '$name' ('$bin') not found on PATH"
}

# have_tool "binary" — true if present (optional tools).
have_tool() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
# YAML config loader (scalar `key: value` pairs only).
#
# Each key becomes a variable C4_<UPPERCASE_KEY> set with `printf -v` — no
# `eval`, so a hostile value cannot execute. Nested mappings and lists are
# intentionally unsupported: the config surface is deliberately flat.
# ---------------------------------------------------------------------------
load_yaml_config() {
  local yaml_file="$1"
  [ -f "$yaml_file" ] || die "config file not found: $yaml_file"

  local line key value key_up
  while IFS= read -r line || [ -n "$line" ]; do
    # strip leading whitespace
    line="${line#"${line%%[![:space:]]*}"}"
    # skip blanks and comments
    case "$line" in ''|\#*) continue ;; esac

    if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*:[[:space:]]*(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
      # strip inline comment (only when preceded by whitespace, so URLs survive)
      value="$(printf '%s' "$value" | sed -E 's/[[:space:]]+#.*$//')"
      # trim trailing whitespace
      value="${value%"${value##*[![:space:]]}"}"
      # strip matching surrounding quotes
      if [[ "$value" =~ ^\"(.*)\"$ ]]; then value="${BASH_REMATCH[1]}"; fi
      if [[ "$value" =~ ^\'(.*)\'$ ]]; then value="${BASH_REMATCH[1]}"; fi

      key_up="$(printf '%s' "$key" | tr '[:lower:]' '[:upper:]')"
      printf -v "C4_${key_up}" '%s' "$value"
    fi
  done < "$yaml_file"
}

# cfg KEY [DEFAULT] — read C4_<KEY> with a fallback (indirect expansion).
cfg() {
  local name="C4_$1"
  printf '%s' "${!name:-${2:-}}"
}
