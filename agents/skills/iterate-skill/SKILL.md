---
name: iterate-skill
description: Improve an existing agent skill, or create a new one, from what was learned in the current conversation — edit it in a dedicated git worktree of the repository that holds the skills, commit, push, update the live checkout and remove the worktree. Use when the user asks to "itérer sur le skill X", "mets à jour le skill avec tes enseignements", "améliore le skill", "fais un skill pour…", "capitalise ce qu'on vient d'apprendre dans le skill", or right after a skill was used and fell short.
---

# Iterate on a skill

Skills are symlinked from a git repository (typically
`~/.claude/skills/<name>` → `~/.agents/skills/<name>` →
`~/dotfiles/agents/skills/<name>`). That checkout is live: every session
reads it. Never edit it in place; work in a worktree, then fast-forward
the checkout once the change is pushed.

## Steps

1. Locate the repository holding the skills:

   ```bash
   SKILL_DIR="$(readlink -f "$HOME/.claude/skills/<name>")"
   REPO="$(git -C "$SKILL_DIR" rev-parse --show-toplevel)"
   SKILLS_PATH="${SKILL_DIR#"$REPO"/}"
   ```

   For a new skill, resolve an existing sibling instead and use its parent
   directory. If the skill is not a symlink into a git repository (plain
   directory, installed by a skills manager), stop and ask the user where
   it should live.

2. Read the repository conventions: its `CLAUDE.md`/`AGENTS.md`,
   `git log --oneline -10 -- "$SKILLS_PATH"` for the commit style and
   language, and `git log --merges --oneline -5` to know whether changes
   land by direct push on the default branch or through pull requests.

3. Create the worktree from the up-to-date default branch:

   ```bash
   git -C "$REPO" fetch -q origin
   DEFAULT="$(git -C "$REPO" symbolic-ref --short refs/remotes/origin/HEAD | sed 's|^origin/||')"
   git -C "$REPO" worktree add -q "worktrees/skills-<slug>" -b "skills-<slug>" "origin/$DEFAULT"
   ```

   Check that `worktrees/` is ignored (`git -C "$REPO" check-ignore worktrees/x`);
   otherwise create the worktree next to the repository instead of inside it.
   One worktree can hold several skills when the user asks for them together.

4. Write the learnings into the skill, reading it entirely first:
   - only what this conversation established: failures met and their fix,
     what made the result good, pitfalls that cost a retry;
   - generic rules first, project details only as examples;
   - in the skill's existing structure and voice, without duplicating a
     rule it already states (amend that rule instead);
   - extend the `description` when the skill should now trigger on new
     requests;
   - helpers that were improvised during the conversation (scripts,
     snippets) go next to `SKILL.md` as files, referenced from it.

   For a new skill: a `SKILL.md` with `name` and a `description` stating
   what it does and when to use it, including the user's own phrasings;
   then steps an agent can follow without the conversation.

5. Commit in the worktree, one commit per skill, following the
   repository's message conventions (the why in the body). Only stage the
   skill files you wrote.

6. Integrate:
   - direct-push repository: `git rebase "origin/$DEFAULT"` then
     `git push origin "HEAD:$DEFAULT"`;
   - pull-request repository: push the branch and open the pull request,
     then stop here and leave the worktree until it is merged.

7. Update the live checkout, only if it is on the default branch and
   clean, otherwise tell the user what is left to do:

   ```bash
   git -C "$REPO" merge -q --ff-only "origin/$DEFAULT"
   ```

   A new skill also needs its symlink, the way the repository installs the
   others (e.g. `ln -s "$REPO/$SKILLS_PATH" "$HOME/.agents/skills/<name>"`,
   or the repository's install script).

8. Remove the worktree and its branch:

   ```bash
   git -C "$REPO" worktree remove "worktrees/skills-<slug>"
   git -C "$REPO" branch -d "skills-<slug>"
   ```

9. Report the commits pushed and, in one line each, what changed in each
   skill.
