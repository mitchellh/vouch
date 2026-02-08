use std/assert

# `main` is special in Nu and isn't imported into scope via `use ... *`,
# but it should still be callable through the module namespace.
export def "test module main is callable via module namespace" [] {
  let result = do { nu -c 'use vouch *; vouch main' } | complete
  assert equal $result.exit_code 0 $"stderr: ($result.stderr | str trim)"
  assert ($result.stdout | str contains "Usage: vouch <command>")
}

export def "test module help for main works via module namespace" [] {
  let result = do { nu -c 'use vouch *; help vouch main' } | complete
  assert equal $result.exit_code 0 $"stderr: ($result.stderr | str trim)"
}
