# Prompt: check the claims of a UX review

Fill the placeholders, write it to a file, run it through
`codex-review.sh <file> medium`.

```
You are checking a UX review of the pull request <repo>#<n>, diff
`git diff <base>...<head>`. The review was written from screenshots of the
running app; some of its claims about behaviour may be wrong. You do not
judge the UX and you add no finding.

For every claim below that states how the app behaves (what is saved or
lost, what is shown to whom, what a button does, timings, validations,
permissions), read the code and answer one line per finding:

U<n>: holds | wrong | unclear - <file:line> - <the fact, one sentence>

- holds: the code does what the claim says.
- wrong: the code contradicts it; cite the line that shows it.
- unclear: the code does not settle it (runtime data, a third party).

Claims about layout, wording or visual hierarchy are out of scope: answer
"U<n>: visual" for those.

Do not speculate. If you cannot find the code a claim is about, answer
unclear and say what you searched.

Draft findings:

<paste U1…Un: title, Constat, Recommandation>
```
