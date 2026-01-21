Run /bugfix $1

Then:
1. Push the branch
2. Create a PR if none exists (`gh pr create`)
3. Request Claude review: `gh pr comment PR_ID --body "@claude review"`

Use `gh pr list --head BRANCH_NAME` to find PR if needed.
