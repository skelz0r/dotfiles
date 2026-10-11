---
name: grilling
description: Grill the user relentlessly about a plan, decision or idea, one round of questions at a time, until every branch of the design tree is settled and nothing is silently assumed. Use when the user wants to stress-test their thinking, runs /grilling, says "grill me", "cuisine-moi", "challenge mon plan", "pose-moi toutes les questions avant de coder", "on aligne la spec", or before handing a fuzzy topic to /start.
---

# Grilling

Adapted from Matt Pocock's `grilling` skill
(https://github.com/mattpocock/skills, MIT, see `LICENSE`).

Interview the user relentlessly until you reach a shared understanding.
Map this as a design tree: every decision branches into the decisions
that hang off it.

## Rounds

Work the tree in rounds. The frontier is every decision whose
prerequisites are already settled: the questions you can ask now without
guessing at answers you haven't heard yet. Ask the whole frontier in one
round, each question with your recommended answer, then wait for the
answers before the next round.

Ask with AskUserQuestion when it is available: up to four questions per
call, the recommended option first with "(Recommended)" in its label,
several calls in a row when the frontier is wider. Otherwise, number the
questions in plain text, a short title, the body with its options, then
the recommended answer, worded so "yes" accepts it. Questions in the
user's language, terse, no filler.

Each round reshapes the tree: settled decisions push the frontier outward
and unblock the questions that depended on them. Recompute the frontier
and ask the next round. A question whose answer depends on another
question still open in this round belongs to a later round.

Grilling means pushing back: when an answer contradicts a fact you found,
an earlier decision or a constraint of the project, say so bluntly and
ask again rather than recording it.

## Facts versus decisions

Finding facts is your job, never the user's. When a frontier question
needs a fact from the environment (code, git history, tickets, tools),
dispatch a sub-agent (Explore) to find it; don't ask the user for
anything you could look up yourself. Don't block on it: a running
exploration is an unsettled prerequisite, so only the questions
downstream of it wait for its report; ask the rest of the frontier now.
The decisions are the user's: put each to them and wait.

## End

The session is done when the frontier is empty: every branch visited,
nothing left silently assumed. Recap the settled decisions, the options
rejected and the cases the user gave, then do not act on it until the
user confirms you have reached a shared understanding.

When the next step is implementation, offer to hand it off with `/start`:
the recap is the core of its brief, the user's cases become the cases to
test.
