Can you fix the latest build on GitHub Actions?
Use `gh` to do so, you can get the latest run with `gh run list -b BRANCH_NAME`
with `BRANCH_NAME` this branch.
Focus only on failing cases, don't try to find optimizations or improvements or
strange behaviors.
If it's a rails app, check within logs lines beginning with `rspec ` for list.
