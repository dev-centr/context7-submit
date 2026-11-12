#!/usr/bin/env bash
set -euo pipefail
bin="${1:?path to ctx7-submit}"
if [[ ! -f "$bin" && -f "$bin.exe" ]]; then
  bin="$bin.exe"
fi
"$bin" --version
"$bin" --help >/dev/null
set +e
"$bin" >/dev/null
code=$?
set -e
test "$code" -eq 2
