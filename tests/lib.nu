use std/assert

use ../vouch/file.nu ["from td", "to td"]
use ../vouch/lib.nu [add-user, check-user, denounce-user, parse-comment, remove-user]

def sample-records [] {
  "# Comment
mitchellh
github:alice
-github:badguy
-github:spammer Reason here" | from td
}

# --- check-user ---

export def "test check-user finds vouched user" [] {
  let result = sample-records | check-user "mitchellh"
  assert equal $result "vouched"
}

export def "test check-user finds vouched user with platform" [] {
  let result = sample-records | check-user "github:alice"
  assert equal $result "vouched"
}

export def "test check-user finds denounced user" [] {
  let result = sample-records | check-user "github:badguy"
  assert equal $result "denounced"
}

export def "test check-user returns unknown for missing user" [] {
  let result = sample-records | check-user "nobody"
  assert equal $result "unknown"
}

export def "test check-user is case insensitive" [] {
  let result = sample-records | check-user "MitchellH"
  assert equal $result "vouched"
}

export def "test check-user matches with default platform" [] {
  let result = sample-records | check-user "alice" --default-platform github
  assert equal $result "vouched"
}

export def "test check-user denounced with default platform" [] {
  let result = sample-records | check-user "badguy" --default-platform github
  assert equal $result "denounced"
}

# --- add-user ---

export def "test add-user adds new user" [] {
  let result = sample-records | add-user "newuser"
  let status = $result | check-user "newuser"
  assert equal $status "vouched"
}

export def "test add-user adds user with platform" [] {
  let result = sample-records | add-user "github:newuser"
  let status = $result | check-user "github:newuser"
  assert equal $status "vouched"
}

export def "test add-user replaces denounced user" [] {
  let result = sample-records | add-user "github:badguy"
  let status = $result | check-user "github:badguy"
  assert equal $status "vouched"
}

export def "test add-user preserves comments" [] {
  let result = sample-records | add-user "newuser"
  let comments = $result | where type == "comment"
  assert equal ($comments | length) 1
}

export def "test add-user result is sorted" [] {
  let result = sample-records | add-user "zzz"
  let entries = $result | where { |r| $r.type == "vouch" or $r.type == "denounce" }
  let usernames = $entries | get username
  let sorted = $usernames | sort -i
  assert equal $usernames $sorted
}

# --- denounce-user ---

export def "test denounce-user denounces a user" [] {
  let result = sample-records | denounce-user "newbad"
  let status = $result | check-user "newbad"
  assert equal $status "denounced"
}

export def "test denounce-user with reason" [] {
  let result = sample-records | denounce-user "newbad" "spam"
  let entry = $result | where username == "newbad" | first
  assert equal $entry.details "spam"
}

export def "test denounce-user replaces vouched user" [] {
  let result = sample-records | denounce-user "mitchellh"
  let status = $result | check-user "mitchellh"
  assert equal $status "denounced"
}

export def "test denounce-user preserves comments" [] {
  let result = sample-records | denounce-user "newbad"
  let comments = $result | where type == "comment"
  assert equal ($comments | length) 1
}

# --- remove-user ---

export def "test remove-user removes vouched user" [] {
  let result = sample-records | remove-user "mitchellh"
  let status = $result | check-user "mitchellh"
  assert equal $status "unknown"
}

export def "test remove-user removes denounced user" [] {
  let result = sample-records | remove-user "github:badguy"
  let status = $result | check-user "github:badguy"
  assert equal $status "unknown"
}

export def "test remove-user preserves other entries" [] {
  let result = sample-records | remove-user "mitchellh"
  let status = $result | check-user "github:alice"
  assert equal $status "vouched"
}

export def "test remove-user preserves comments" [] {
  let result = sample-records | remove-user "mitchellh"
  let comments = $result | where type == "comment"
  assert equal ($comments | length) 1
}

export def "test remove-user noop for missing user" [] {
  let before = sample-records
  let after = $before | remove-user "nobody"
  assert equal ($after | length) ($before | length)
}

# --- roundtrip ---

export def "test add-user roundtrips through td format" [] {
  let result = sample-records | add-user "newuser" | to td | from td | check-user "newuser"
  assert equal $result "vouched"
}

export def "test denounce-user roundtrips through td format" [] {
  let result = sample-records | denounce-user "newbad" "reason" | to td | from td | check-user "newbad"
  assert equal $result "denounced"
}

# --- parse-comment ---

export def "test parse-comment vouch keyword only" [] {
  let result = parse-comment "vouch"
  assert equal $result.action "vouch"
  assert equal $result.user null
  assert equal $result.reason ""
}

export def "test parse-comment vouch with user" [] {
  let result = parse-comment "vouch @alice"
  assert equal $result.action "vouch"
  assert equal $result.user "alice"
  assert equal $result.reason ""
}

export def "test parse-comment vouch with user and reason" [] {
  let result = parse-comment "vouch @alice good contributor"
  assert equal $result.action "vouch"
  assert equal $result.user "alice"
  assert equal $result.reason "good contributor"
}

export def "test parse-comment vouch with reason no user" [] {
  let result = parse-comment "vouch trusted person"
  assert equal $result.action "vouch"
  assert equal $result.user null
  assert equal $result.reason "trusted person"
}

export def "test parse-comment denounce keyword only" [] {
  let result = parse-comment "denounce"
  assert equal $result.action "denounce"
  assert equal $result.user null
  assert equal $result.reason ""
}

export def "test parse-comment denounce with user and reason" [] {
  let result = parse-comment "denounce @badguy spammer"
  assert equal $result.action "denounce"
  assert equal $result.user "badguy"
  assert equal $result.reason "spammer"
}

export def "test parse-comment unvouch keyword only" [] {
  let result = parse-comment "unvouch"
  assert equal $result.action "unvouch"
  assert equal $result.user null
  assert equal $result.reason ""
}

export def "test parse-comment unvouch with user" [] {
  let result = parse-comment "unvouch @alice"
  assert equal $result.action "unvouch"
  assert equal $result.user "alice"
  assert equal $result.reason ""
}

export def "test parse-comment unvouch ignores trailing text" [] {
  let result = parse-comment "unvouch @alice some reason"
  assert equal $result.action null
}

export def "test parse-comment no match" [] {
  let result = parse-comment "hello world"
  assert equal $result.action null
  assert equal $result.user null
  assert equal $result.reason ""
}

export def "test parse-comment case insensitive" [] {
  let result = parse-comment "VOUCH @Alice"
  assert equal $result.action "vouch"
  assert equal $result.user "Alice"
}

export def "test parse-comment leading whitespace" [] {
  let result = parse-comment "  vouch @alice"
  assert equal $result.action "vouch"
  assert equal $result.user "alice"
}

export def "test parse-comment custom keyword" [] {
  let result = parse-comment "lgtm @alice" --vouch-keyword [lgtm approve]
  assert equal $result.action "vouch"
  assert equal $result.user "alice"
}

export def "test parse-comment allow-vouch false" [] {
  let result = parse-comment "vouch @alice" --allow-vouch=false
  assert equal $result.action null
}

export def "test parse-comment allow-denounce false" [] {
  let result = parse-comment "denounce @badguy" --allow-denounce=false
  assert equal $result.action null
}

export def "test parse-comment allow-unvouch false" [] {
  let result = parse-comment "unvouch @alice" --allow-unvouch=false
  assert equal $result.action null
}

export def "test parse-comment newline injection parses first line only" [] {
  let result = parse-comment "denounce @user\n-github:victim injected"
  assert equal $result.action "denounce"
  assert equal $result.user "user"
  assert equal $result.reason ""
}

export def "test parse-comment multiline body parses first line only" [] {
  let result = parse-comment "denounce @ditherdude\n-github:someLegitContributor haha"
  assert equal $result.action "denounce"
  assert equal $result.user "ditherdude"
  assert equal $result.reason ""
}

# --- web of trust priority ---

export def "test local vouch overrides inherited denounce" [] {
  let local = "alice" | from td
  let inherited = "-alice" | from td
  let merged = $local | append $inherited
  let result = $merged | check-user "alice"
  assert equal $result "vouched"
}

export def "test local denounce overrides inherited vouch" [] {
  let local = "-bob" | from td
  let inherited = "bob" | from td
  let merged = $local | append $inherited
  let result = $merged | check-user "bob"
  assert equal $result "denounced"
}

export def "test falls through to inherited for unknown local user" [] {
  let local = "alice" | from td
  let inherited = "charlie" | from td
  let merged = $local | append $inherited
  let result = $merged | check-user "charlie"
  assert equal $result "vouched"
}

export def "test unknown across all files returns unknown" [] {
  let local = "alice" | from td
  let inherited = "bob" | from td
  let merged = $local | append $inherited
  let result = $merged | check-user "nobody"
  assert equal $result "unknown"
}
