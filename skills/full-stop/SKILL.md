---
name: full-stop
description: Trigger this if the user says 'full stop', even as a closing "Full stop." that reads like emphasis. Takes a change unattended to a green, reviewed draft PR that waits for the user.
---

# Full Stop

Adapted from `full-stop` / `full-send` in
[t3dotgg/tstack](https://github.com/t3dotgg/tstack) (MIT).

If the user triggered this, they are not watching this thread and want the
work done end-to-end on its own. Your updates and your final message go unread
until long after you stop. You own the work from its current state to a green,
reviewed **draft** PR. The user marks it ready and gets it merged.

If the user did not explicitly say "full stop" in some clear way, do not assume
this autonomy.

## What the request grants

- Commit, push, and merge the base branch into this task's branch, and into
  the branches stacked on it.
- Use the test methods Proof needs without asking first: the browser, a dev
  server, the local instance, screenshots. Rules about *how* to test still
  apply (`shopware-worktree-dev`, `shopware-local-dev`); this only removes the
  ask-first step.

## What it never grants

- Merging the PR, enabling auto-merge, pushing to `trunk`, bypassing branch
  protection.
- `gh pr ready`, or creating the PR without `--draft`. The PR stays a draft.
- Rebasing or force-pushing a pushed branch. Integrate with merge commits.
- Posting on GitHub: no comments, replies, reviews, or resolved threads.
  Drafted replies go into the report.
- Deleting data, touching production, closing a PR, or changing things outside
  the repo.

## Steps

1. **Finish the change.** Complete the goal with the smallest change that
   works. Fix the case that happened, not every case that could. On `trunk`,
   create a branch first.
2. **Prove it.** Get proof for every change you made. See "Proof".
3. **Get feedback.** Run the `opus-loop` skill on the diff.
4. **File the PR** with the `pr-create` skill: draft, its labels, assignee, and
   description rules. Merge the latest base into the branch first. Add one
   short line under the template's "How to test" section saying how you proved
   the change. If a PR for this branch exists, update its description in place
   per `pr-create`; never overwrite it from a local draft.
5. **Babysit the PR** with the `babysit-pr` skill. Fix real findings and CI
   failures. Get proof for each fix before you push it.
6. **Stop at the gate.** See "Handoff".

Stay active from step 1 to step 6. If you end your turn while checks are
pending, the work stops, because nobody prompts you again. Wait with the
watcher from `babysit-pr`, so something wakes you when the PR changes.

## Proof

Proof is evidence you observed yourself in this session: command output, a
reproduction, a screenshot. Use the most direct proof the change allows:

- Reproduce the original failure, apply the fix, then watch the same
  reproduction pass.
- Run the checks the touched files need (lint, typecheck, focused tests). CI
  runs the full suite on the draft.
- Add one focused test that fails without the fix, when the behavior has none.
- For UI and runtime behavior, open the app and look at the change. Green mocked
  tests do not prove that the user experience works.

When you cannot find a way to prove a change, you do not have full confidence.
Ask the user.

## Handoff

The gate, all true on the latest commit:

- Your proof covers every change in the diff.
- The required checks are green (`pr-wait --until green` exited 0).
- Every bot or reviewer finding is fixed, or listed in the report with a reason
  and a drafted reply.
- The branch has the latest base merged in, and the stack above it is merged up.

Then fetch and check the live PR: open, still a draft, head equals your last
push. If someone else merged or closed it, report that instead.

- **Ready for you:** the gate passes. Leave it as a draft.
- **Blocked:** say what prevents the gate, what you tried, and what is needed.

Report: PR link, final head, proof, opus-loop outcome, CI outcome, drafted
replies, stack branches you merged into, each decision you made for the user,
and remaining risks.

## Asking the user

A question in a normal message goes unseen, and the thread looks done. Ask with
`AskUserQuestion`, with all the context in the question: the PR link, what
blocks you, and the options with your recommendation first.

Ask only when you cannot continue alone:

- You cannot prove the change.
- The gate cannot pass, and you cannot fix that yourself.
- The next step is in "What it never grants".
- The goal is ambiguous in a way that changes the result.
- Another PR makes this one obsolete.

Decide everything else yourself with sensible defaults, and list those decisions
in the report. If the question tool returns no answer, leave the PR as it is
and start your final message with the question.
