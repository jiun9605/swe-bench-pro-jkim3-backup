#!/bin/bash
# Use go test -json for hardened grading (prevents fake --- PASS: lines via stdout)
# Parser will consume only Action=pass/fail events and ignore Output events.

set +e

run_all_tests() {
  echo "Running all tests..."
  cd /app
  # -json emits machine-readable events; -race enables race detector
  # Do not use || true - preserve exit code for harness
  go test -json -race ./... 2>&1
  return $?
}

run_selected_tests() {
  local test_files=("$@")
  echo "Running selected tests: ${test_files[@]}"
  cd /app
  # For Go, we run full package but filter output later via parser (JSON-based)
  go test -json -race ./... 2>&1
  return $?
}

if [ $# -eq 0 ]; then
  run_all_tests
  exit $?
fi

if [[ "$1" == *","* ]]; then
  IFS=',' read -r -a TEST_FILES <<< "$1"
else
  TEST_FILES=("$@")
fi

run_selected_tests "${TEST_FILES[@]}"
exit $?
