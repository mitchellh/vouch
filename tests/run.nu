#!/usr/bin/env nu

# Run all tests in the test suite.
#
# Discovers and runs all `test *` commands from test modules.
# Uses Nu's `std/assert` for assertions.
#
# Examples:
#
#   nu tests/run.nu
#   nu tests/run.nu --filter "from-td"
#   nu tests/run.nu --fast
#   nu tests/run.nu --slow

def main [
  --filter: string = "",  # Only run tests matching this substring
  --fast,                  # Skip tests marked as slow (named "test slow ...")
  --slow,                  # Only run tests marked as slow
] {
  # Discover test modules: every .nu file in this directory except run.nu.
  const dir = path self | path dirname
  let modules = (
    glob ($dir | path join "*.nu")
    | where { |f| ($f | path basename) != "run.nu" }
    | sort
    | each { |f|
      { name: ($f | path basename | str replace ".nu" ""), path: $f }
    }
  )

  mut total = 0
  mut passed = 0
  mut skipped = 0
  mut failed = 0
  mut failures = []

  for mod in $modules {
    # Import the module in a subprocess and list all exported commands
    # whose name starts with "test ".
    let commands = (
      nu -c $'use ($mod.path) *; scope commands | where name =~ "^test " | get name | to json'
      | from json
    )

    for test_name in $commands {
      if (not ($filter | is-empty)) and (not ($test_name | str contains $filter)) {
        continue
      }

      let is_slow = ($test_name | str starts-with "test slow ")

      if $fast and $is_slow {
        $skipped += 1
        print $"  (ansi yellow)⊘(ansi reset) ($mod.name): ($test_name)"
        continue
      }

      if $slow and (not $is_slow) {
        $skipped += 1
        print $"  (ansi yellow)⊘(ansi reset) ($mod.name): ($test_name)"
        continue
      }

      $total += 1

      # Run each test in its own subprocess so failures are isolated.
      let result = do {
        nu -c $'use ($mod.path) *; ($test_name)'
      } | complete

      if $result.exit_code == 0 {
        $passed += 1
        print $"  (ansi green)✓(ansi reset) ($mod.name): ($test_name)"
      } else if ($result.stderr | str contains "SKIP:") {
        $skipped += 1
        $total -= 1
        print $"  (ansi yellow)⊘(ansi reset) ($mod.name): ($test_name)"
      } else {
        $failed += 1
        $failures = ($failures | append { module: $mod.name, test: $test_name, stderr: $result.stderr })
        print $"  (ansi red)✗(ansi reset) ($mod.name): ($test_name)"
      }
    }
  }

  # Print summary.
  print ""
  let skip_msg = if $skipped > 0 {
    $", ($skipped) skipped"
  } else {
    ""
  }
  print $"(ansi white_bold)Results: ($passed)/($total) passed($skip_msg)(ansi reset)"

  # If any tests failed, print details and exit with a non-zero code.
  if $failed > 0 {
    print ""
    print $"(ansi red_bold)Failures:(ansi reset)"
    for f in $failures {
      print $"  (ansi red)✗(ansi reset) ($f.module): ($f.test)"
      print $"    ($f.stderr | str trim)"
    }
    exit 1
  }
}
