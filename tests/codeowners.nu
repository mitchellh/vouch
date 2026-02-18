use std/assert

use ../vouch/codeowners.nu [parse-codeowners]

def sample-codeowners-file [] {
  let dir = (mktemp -d)
  let path = ([$dir "CODEOWNERS"] | path join)
  "# Sample CODEOWNERS
/docs/ @acme/docs
/src/ @acme/core @bob
/src/special.txt @acme/ops @bob"
    | save -f $path
  $path
}

export def "test codeowners-parse returns owner files table" [] {
  let file = sample-codeowners-file
  let rules = open -r $file | parse-codeowners
  assert equal $rules [
    {
      owner: "acme/docs"
      files: ["/docs/"]
    }
    {
      owner: "acme/core"
      files: ["/src/"]
    }
    {
      owner: "bob"
      files: ["/src/", "/src/special.txt"]
    }
    {
      owner: "acme/ops"
      files: ["/src/special.txt"]
    }
  ]
}
