# Global RuboCop cops

`custom.rb` is loaded by every RuboCop of the machine through
`RUBOCOP_OPTS`, exported by `zshenv`. It defines the `Custom/` cops,
all disabled by default (`default.yml`): a project opts in from its own
`.rubocop.yml`.

| Cop | Rule |
|---|---|
| `Custom/DuckTyping` | no `is_a?`, `kind_of?`, `respond_to?` |
| `Custom/NoComments` | no comment but magic comments, `rubocop:` and `:nocov:` directives, shebangs |
| `Custom/NoFixedSleep` | no `sleep` / `Kernel.sleep` in `spec/**/*.rb` |

## Opting in

```yaml
inherit_from:
  - .rubocop_ratchet.yml

Custom/NoComments:
  Enabled: true
```

then `rubocop-ratchet --init Custom/NoComments` to write the first
quotas.

## Quotas (ratchet)

`NoComments` and `NoFixedSleep` include `Custom::Ratchet`: each file has
a quota of offenses, read from the cop's `Allow:` (paths relative to the
`.rubocop.yml`), stored in `.rubocop_ratchet.yml` and written only by
`rubocop-ratchet`:

- as many offenses as the quota: nothing is reported;
- more: every offense of the file is reported;
- fewer: one offense asks to lower the quota.

`rubocop-ratchet` lowers every quota, `--init COP` writes the first
ones. A quota never goes up, and nothing is written when RuboCop could
not inspect every file.

## Where `RUBOCOP_OPTS` is not set

A cop named in `.rubocop.yml` but not defined makes RuboCop fail
(`unrecognized cop`). A project that opts in, and whose CI or other
contributors do not load these dotfiles, needs either:

- a copy of the cops under its `lib/rubocop/cop/custom/`, required from
  its `.rubocop.yml`: each file returns early when the cop is already
  defined, so with `RUBOCOP_OPTS` the dotfiles version wins and the
  copy is skipped (superdocu does this; keep the copy in sync);
- or `--ignore-unrecognized-cops` in its `.rubocop`, and the cops are
  simply not checked there.

## Tests

`dotfiles-test tests`: `test/rubocop/*_spec.rb` for the cops,
`test/rubocop-cops.bats` for the opt-in and `rubocop-ratchet`.
