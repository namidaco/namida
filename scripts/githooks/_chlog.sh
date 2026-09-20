#!/bin/sh
# resolves a python interpreter and the repo's chlog.py, sourced by the hooks.

CHLOG_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
CHLOG_PY="$CHLOG_ROOT/scripts/chlog.py"
[ -f "$CHLOG_PY" ] || exit 0

CHLOG_PYTHON=""
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1; then
    CHLOG_PYTHON="$candidate"
    break
  fi
done
if [ -z "$CHLOG_PYTHON" ] && command -v py >/dev/null 2>&1; then
  CHLOG_PYTHON="py -3"
fi
if [ -z "$CHLOG_PYTHON" ]; then
  echo "chlog: no python found, skipping commit message checks" >&2
  exit 0
fi
