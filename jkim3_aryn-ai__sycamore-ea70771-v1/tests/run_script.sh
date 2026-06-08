#!/bin/bash
set -e

run_all_tests() {
  echo "Running all tests..."
  cd /app/lib/sycamore
  if command -v poetry >/dev/null 2>&1; then
    poetry run python -m pytest -v --tb=short || true
  else
    python -m pytest -v --tb=short || true
  fi
}

run_selected_tests() {
  local test_files=("$@")
  echo "Running selected tests: ${test_files[@]}"
  cd /app/lib/sycamore

  # Use poetry run if available, otherwise fallback to python
  if command -v poetry >/dev/null 2>&1; then
    PYTEST_CMD="poetry run python -m pytest"
  else
    PYTEST_CMD="python -m pytest"
  fi

  for test_file in "${test_files[@]}"; do
    echo "Running test: $test_file"
    test_path=$(echo "$test_file" | sed 's/::.*//')
    $PYTEST_CMD "$test_path" -v --tb=short || true
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
