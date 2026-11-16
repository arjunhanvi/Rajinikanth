#!/bin/bash
# Parses every script and reports GDScript errors with file:line (used locally and in CI).
cd "$(dirname "$0")/.."
out=$(timeout 300 godot --headless --path . --import 2>&1 | grep -A1 -E "SCRIPT ERROR|Parse Error" | grep -E "Parse Error|at: " | paste - - | sort -u)
if [ -n "$out" ]; then echo "$out"; exit 1; fi
echo "scripts OK"
