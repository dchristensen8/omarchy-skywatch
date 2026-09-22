#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
export OMASTORM_ROOT="$PWD"
# Skywatch radar bootstrap: install or verify the pinned Omastorm engine and
# ensure the daemon is running. Runs detached on first radar open.
if [[ ${1:-} == --ensure ]]; then
  if [[ -n ${OMASTORM_BOOTSTRAP_LOG:-} ]]; then
    mkdir -p "$(dirname "$OMASTORM_BOOTSTRAP_LOG")"
    exec 2> "$OMASTORM_BOOTSTRAP_LOG"
  fi
  engine=$(bash scripts/fetch-engine.sh --print-path)
  exec "$engine" ensure
fi
echo "Skywatch radar run.sh: expected --ensure" >&2
exit 1