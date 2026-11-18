#!/usr/bin/env bats

load helpers

setup() {
  local ruby_bin
  ruby_bin="$(dirname "$(rbenv which rubocop 2> /dev/null || command -v rubocop)")"
  setup_sandbox
  export PATH="$ruby_bin:$PATH"
  export RUBOCOP_OPTS="--require $REPO_ROOT/config/rubocop/custom.rb"
  PROJECT="$BATS_TEST_TMPDIR/project"
  mkdir -p "$PROJECT/spec"
  cd "$PROJECT"
  printf '# frozen_string_literal: true\n\n# prose\nputs 1.is_a?(Integer)\n' > app.rb
  printf '# frozen_string_literal: true\n\nsleep 1\n' > spec/app_spec.rb
}

base_config() {
  printf 'AllCops:\n  NewCops: disable\n  SuggestExtensions: false\nStyle/NumericPredicate:\n  Enabled: false\n'
}

custom_offenses() {
  rubocop --cache false --format emacs 2> /dev/null | grep -o 'Custom/[A-Za-z]*' | sort | uniq -c | awk '{print $2 "=" $1}' | paste -sd' ' -
}

@test "a project without any config of the custom cops gets none of their offenses" {
  base_config > .rubocop.yml

  assert_equal "$(custom_offenses)" ""
}

@test "a project that enables the custom cops gets their offenses" {
  { base_config; printf 'Custom/NoComments:\n  Enabled: true\nCustom/NoFixedSleep:\n  Enabled: true\nCustom/DuckTyping:\n  Enabled: true\n'; } > .rubocop.yml

  assert_equal "$(custom_offenses)" "Custom/DuckTyping=1 Custom/NoComments=1 Custom/NoFixedSleep=1"
}

@test "rubocop-ratchet --init sets the quota to the current offenses, then a new one breaks the build" {
  { base_config; printf 'inherit_from: .rubocop_ratchet.yml\nCustom/NoComments:\n  Enabled: true\n'; } > .rubocop.yml

  "$REPO_ROOT/bin/rubocop-ratchet" --init Custom/NoComments
  assert_equal "$(custom_offenses)" ""

  printf '# another\n' >> app.rb
  "$REPO_ROOT/bin/rubocop-ratchet"
  assert_contains "$(cat .rubocop_ratchet.yml)" "app.rb: 1"
  assert_equal "$(custom_offenses)" "Custom/NoComments=2"
}

@test "rubocop-ratchet lowers a quota once offenses are removed" {
  { base_config; printf 'inherit_from: .rubocop_ratchet.yml\nCustom/NoComments:\n  Enabled: true\n'; } > .rubocop.yml
  printf '# frozen_string_literal: true\n\n# one\n# two\n' > app.rb
  "$REPO_ROOT/bin/rubocop-ratchet" --init Custom/NoComments

  printf '# frozen_string_literal: true\n\n# one\n' > app.rb
  assert_equal "$(custom_offenses)" "Custom/NoComments=1"

  "$REPO_ROOT/bin/rubocop-ratchet"
  assert_contains "$(cat .rubocop_ratchet.yml)" "app.rb: 1"
  assert_equal "$(custom_offenses)" ""
}

@test "rubocop-ratchet refuses to initialise a cop twice" {
  { base_config; printf 'inherit_from: .rubocop_ratchet.yml\n'; } > .rubocop.yml
  "$REPO_ROOT/bin/rubocop-ratchet" --init Custom/NoComments

  run "$REPO_ROOT/bin/rubocop-ratchet" --init Custom/NoComments
  assert_equal "$status" 1
  assert_contains "$output" "already has a quota"
}

@test "rubocop-ratchet writes nothing when a file cannot be parsed" {
  { base_config; printf 'inherit_from: .rubocop_ratchet.yml\n'; } > .rubocop.yml
  printf 'def (\n' > broken.rb

  run "$REPO_ROOT/bin/rubocop-ratchet" --init Custom/NoComments
  assert_equal "$status" 1
  assert_contains "$output" "could not inspect broken.rb"
  [[ ! -e .rubocop_ratchet.yml ]]
}

@test "loading the custom cops keeps the preview defaults of the other cops" {
  printf 'AllCops:\n  Preview: true\n  NewCops: disable\n  SuggestExtensions: false\n' > .rubocop.yml
  printf "# frozen_string_literal: true\n\nsource 'https://rubygems.org'\n\ngem 'zeitwerk'\ngem 'rack'\n" > Gemfile

  run rubocop --cache false --only Bundler/OrderedGems Gemfile
  assert_equal "$status" 0
}

@test "a quota written from the root holds for a directory with its own .rubocop.yml" {
  { base_config; printf 'inherit_from: .rubocop_ratchet.yml\nCustom/NoComments:\n  Enabled: true\n'; } > .rubocop.yml
  printf 'inherit_from: ../.rubocop.yml\n' > spec/.rubocop.yml
  printf '# frozen_string_literal: true\n\n# prose\n' > spec/app_spec.rb

  "$REPO_ROOT/bin/rubocop-ratchet" --init Custom/NoComments
  assert_contains "$(cat .rubocop_ratchet.yml)" "spec/app_spec.rb: 1"
  assert_equal "$(custom_offenses)" ""
}

@test "a repository nested in another project ignores the quota file of the parent" {
  { base_config; printf 'inherit_from: .rubocop_ratchet.yml\n'; } > .rubocop.yml
  printf -- '---\nCustom/NoComments:\n  Allow:\n    inner/app.rb: 1\n' > .rubocop_ratchet.yml
  mkdir -p inner/.git
  { base_config; printf 'Custom/NoComments:\n  Enabled: true\n  Allow:\n    app.rb: 1\n'; } > inner/.rubocop.yml
  printf '# frozen_string_literal: true\n\n# prose\n' > inner/app.rb
  cd inner

  assert_equal "$(custom_offenses)" ""
  "$REPO_ROOT/bin/rubocop-ratchet"
  assert_equal "$(cat ../.rubocop_ratchet.yml)" "$(printf -- '---\nCustom/NoComments:\n  Allow:\n    inner/app.rb: 1')"
}
