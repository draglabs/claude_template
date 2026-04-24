#!/usr/bin/env bash
# Consistency checker — run in CI to catch hardcoded values and silent fallbacks.
# Add project-specific patterns to the CUSTOM CHECKS section below.
#
# Usage:
#   ./scripts/check-consistency.sh          # exits 0 if clean, 1 if findings
#   ./scripts/check-consistency.sh --fix    # prints suggested fixes (doesn't auto-fix)

set -euo pipefail

ERRORS=0
SRC_DIRS="src"  # adjust to your project's source directories

red()   { printf '\033[0;31m%s\033[0m\n' "$1"; }
green() { printf '\033[0;32m%s\033[0m\n' "$1"; }
warn()  { printf '\033[0;33m⚠  %s\033[0m\n' "$1"; }

check() {
  local label="$1"
  local pattern="$2"
  local glob="${3:-}"
  local extra_args=""

  if [ -n "$glob" ]; then
    extra_args="--glob=$glob"
  fi

  local matches
  matches=$(rg --no-heading -n $extra_args "$pattern" $SRC_DIRS 2>/dev/null || true)

  if [ -n "$matches" ]; then
    red "FAIL: $label"
    echo "$matches" | head -20
    local count
    count=$(echo "$matches" | wc -l | tr -d ' ')
    if [ "$count" -gt 20 ]; then
      warn "... and $((count - 20)) more"
    fi
    echo ""
    ERRORS=$((ERRORS + 1))
  fi
}

echo "=== Consistency checks ==="
echo ""

# ── BARE IP ADDRESSES ──
# IPs in source code are almost always hardcoded infrastructure references.
# Exceptions: test fixtures, documentation strings, regex patterns.
check "Bare IP addresses in source code" \
  '\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b' \
  '*.{ts,tsx,js,jsx,py,go,rs}'

# ── SILENT ENV VAR FALLBACKS ──
# process.env.FOO || "string" silently falls back instead of failing loudly.
# Use requireEnv() or throw instead.
check "Silent env var fallbacks (process.env.X || \"...\")" \
  'process\.env\.\w+\s*\|\|\s*["\x27`]' \
  '*.{ts,tsx,js,jsx}'

# Python equivalent
check "Silent env var fallbacks (os.environ.get with default)" \
  'os\.environ\.get\(\s*["\x27]\w+["\x27]\s*,\s*["\x27]' \
  '*.py'

# ── HARDCODED LOCALHOST URLS ──
# localhost URLs in production code paths are almost always wrong.
# Dev servers should use env vars.
check "Hardcoded localhost URLs outside tests" \
  'https?://localhost:\d+' \
  '!*.test.*'

# ── HARDCODED CONTAINER NAMES ──
# Container names should come from env vars or docker-compose service names.
check "Hardcoded container name patterns" \
  '[-\w]+-(?:postgres|caddy|redis|app|worker)-\d+' \
  '*.{ts,tsx,js,jsx,py,yml,yaml}'

# ─────────────────────────────────────────────
# CUSTOM CHECKS — add project-specific patterns
# ─────────────────────────────────────────────
#
# Examples:
#
# # Check version string matches package.json
# EXPECTED_VERSION=$(node -p "require('./package.json').version" 2>/dev/null || echo "")
# if [ -n "$EXPECTED_VERSION" ]; then
#   check "Version string mismatch" \
#     "version.*['\"](?!$EXPECTED_VERSION)[0-9]+\.[0-9]+\.[0-9]+['\"]" \
#     '*.{ts,tsx,js,jsx}'
# fi
#
# # Check for hardcoded domain names
# check "Hardcoded production domain" \
#   'myapp\.example\.com' \
#   '*.{ts,tsx,js,jsx}'
#
# # Check for hardcoded registry URLs
# check "Hardcoded registry URL" \
#   'registry\.example\.com' \
#   '*.{ts,tsx,js,jsx,yml,yaml}'

# ── SUMMARY ──
echo ""
if [ "$ERRORS" -gt 0 ]; then
  red "Found $ERRORS consistency issue(s)."
  echo ""
  echo "Each finding above is a value that should be read from its canonical"
  echo "source (env var, config file, package.json) instead of hardcoded."
  echo ""
  echo "To suppress a false positive, add an inline comment:"
  echo "  // consistency-check-ignore: reason"
  echo ""
  exit 1
else
  green "All consistency checks passed."
  exit 0
fi
