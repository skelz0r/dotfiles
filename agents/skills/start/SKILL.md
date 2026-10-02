---
name: start
description: Hand a development topic off to a fresh Claude session running in its own worktree and tmux tab — create the worktree with the project's own setup script, write a self-contained brief from the current conversation, open a tmux tab with a readable name for the topic and launch dclaude on that brief. Use when the user runs /start, asks to "lance ça dans un worktree", "fais un nouveau tab et worktree", "délègue à une autre session", or wants the topic just discussed to be implemented in parallel.
---

# Start

Counterpart of `/cleanup`: spins up a worktree for a topic and hands it to
a new Claude session in a dedicated tmux tab. Argument: the worktree name
(ticket like `API-7345` or slug like `cnav-nir`), optionally followed by
extra instructions. Without a name, derive a short kebab-case slug from
the topic (2-4 words).

The tab gets its own name: a readable kebab-case slug of the topic
(`omnikles-delegations`, `cnav-nir`), never a bare ticket number, which
says nothing in the tab bar. When the worktree is already named with a
slug, reuse it; when it is a ticket, derive the slug from the topic.

Every project isolates its worktrees differently (ports, Postgres, Redis,
env files), so the setup itself is delegated to the project's script.
This skill only writes the brief and orchestrates tmux.

## Steps

1. Find the primary checkout and the project's conventions:

   ```bash
   PRIMARY_ROOT="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"
   ```

   Read the worktree section of `$PRIMARY_ROOT/CLAUDE.md` (or
   `AGENTS.md`, or the `CLAUDE.md` it points to) to learn which script
   creates worktrees and which arguments it takes. Failing that, look
   for it: `ls "$PRIMARY_ROOT"/bin | grep -iE 'worktree.*(setup|add|new)|(setup|add|new).*worktree'`.
   Known examples: `bin/setup_worktree.sh <name> [branch]`,
   `bin/worktree-setup <name> [branch]`.

   Without a setup script, fall back to
   `git worktree add worktrees/<name> -b feature/<name> origin/develop`
   (adapt the base branch) and tell the user nothing else is isolated.

2. Check the names are free: no existing tmux window with the tab name
   (`tmux list-windows -a -F '#{window_name}'`) and no worktree already
   holding a different topic (`git worktree list`). An existing worktree
   for the same topic is fine: setup scripts are idempotent.

3. Write the brief. The new session starts with no context, so the brief
   must stand on its own, in the user's language:
   - the problem and why it matters (the user's report, ticket id);
   - what was already established in this conversation: diagnosis, file
     paths with line numbers, root cause, so it is not redone;
   - the decisions the user made (and the options they rejected);
   - the points left to the new session's judgment, stated as such;
   - constraints from the project's CLAUDE.md that are easy to miss
     (e.g. SDK regeneration, generated files not to edit by hand);
   - the expected outcome: TDD, atomic commits, PR against the base
     branch — unless the user asked for something else.

   No code, no step-by-step implementation: describe the target, not
   the diff. Save it to the scratchpad directory when one is listed,
   otherwise `mktemp -t start-<name>`. Never inside the repository.

4. Open the tab and launch everything in it, so the user can follow the
   setup output:

   ```bash
   W=$(tmux new-window -d -P -F '#{window_id}' -n <tab name> -c "$PRIMARY_ROOT")
   tmux set-option -w -t "$W" @worktree <name>
   tmux send-keys -t "$W" "<setup script> <name> && cd \"\$(git worktree list --porcelain | awk '/^worktree /{print \$2}' | grep -i '/<name>\$')\" && dclaude \"\$(cat <brief file>)\"" Enter
   ```

   The `@worktree` window option carries the worktree name, so `/cleanup`
   finds the tab whatever it is called, even after a rename.
   The `git worktree list` lookup copes with scripts that lowercase or
   otherwise normalize the name. Always launch Claude with `dclaude`,
   never `claude` directly.

5. Wait for the session to start, polling the pane until the Claude
   prompt shows up or the setup fails (setup can take several minutes:
   gems, packages, databases):

   ```bash
   tmux capture-pane -p -t "$W" | tail -25
   ```

   On failure, show the error and stop: do not retry blindly.

## Report

Tab name, worktree name, path and branch, then two or three lines on what the
brief asks and which points were left to the new session's judgment.
