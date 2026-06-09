#!/bin/bash
set -e

run_all_tests() {
  echo "Running all tests..."
  cd /app
  uv run --frozen pytest -v --tb=short || true
}

run_selected_tests() {
  local test_files=("$@")
  echo "Running selected tests: ${test_files[@]}"
  cd /app

  for test_file in "${test_files[@]}"; do
    echo "Running test: $test_file"
    # Strip ::test_name suffix for pytest file path
    test_path=$(echo "$test_file" | sed 's/::.*//')
    # For our composite scorecard test, run directly to avoid conftest dependencies
    if [[ "$test_path" == *"test_composite_scorecard.py"* ]]; then
      cd / && python "$test_path" || true
    else
      uv run --frozen pytest "$test_path" -v --tb=short || true
    fi
  done
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
