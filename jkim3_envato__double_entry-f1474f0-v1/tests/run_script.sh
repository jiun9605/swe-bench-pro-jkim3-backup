#!/bin/bash
# Run the double_entry RSpec suite under SQLite and emit RSpec's JSON report to
# stdout (parser.py turns that into the grader's {tests:[{name,status}]} shape).
set -e

GEMFILE=/app/spec/support/gemfiles/Gemfile.rails-8.0.x

setup() {
  cd /app
  export DB=sqlite
  export BUNDLE_GEMFILE="$GEMFILE"
  # The suite requires spec/support/database.yml; seed it from the CI sqlite config.
  cp spec/support/database.ci.yml spec/support/database.yml 2>/dev/null || true
}

run_all_tests() {
  setup
  bundle exec rspec --order defined --format json || true
}

run_selected_tests() {
  setup
  local files=()
  for t in "$@"; do
    # Strip any ::example suffix down to the spec file path.
    files+=("$(echo "$t" | sed 's/::.*//')")
  done
  # De-duplicate file paths and run them in a SINGLE invocation so RSpec emits
  # one JSON document covering every selected example.
  local uniq
  uniq=$(printf '%s\n' "${files[@]}" | awk 'NF && !seen[$0]++')
  # shellcheck disable=SC2086
  bundle exec rspec $uniq --order defined --format json || true
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
