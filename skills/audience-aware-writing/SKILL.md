---
name: audience-aware-writing
description: Write text a third party will read — PR/MR descriptions, commit messages, code-review or issue comments, release/upgrade notes, docs, or announcements. Use whenever producing content for readers who were not part of this conversation, to strip internal discussion, set the right context and abstraction level, number points, and keep it tight.
---

# Audience-aware writing

Use this whenever the output will be read by someone who was **not** in this conversation. The failure mode this prevents: writing for *me* (who watched you work) or for *the chat* (with all its discussion), when the real reader has neither.

## Step 1 — Name the reader and their context

Answer briefly, to yourself, before writing:

1. **Who reads this?** Reviewer, future maintainer, extension author, operator, end user…
2. **What do they already know?** The code area, the ticket, the terminology — versus what is new to them.
3. **What were they NOT part of?** Our discussion, the options you rejected, my prompts, your file exploration. None of that belongs in the output unless it changes *their* decision.
4. **What do they need to do or understand** after reading?

If one of these is genuinely unclear and would change the output, ask one short question. Otherwise state your assumption in a single line and proceed.

## Step 2 — Strip conversation residue

Delete:

- "As we discussed", references to this chat, or to my instructions.
- Options considered and rejected — unless the reader must know *why* to trust the choice.
- The play-by-play of how you found things ("I searched…, then read…, then noticed…").
- Anything that only makes sense because *you* read many files. The reader did not.

## Step 3 — Set the altitude, then layer

- Open with the *what* and *why* at the reader's altitude — one to three sentences.
- Only then go deeper, one layer per paragraph or section, general → specific.
- A reviewer should grasp the change from the first paragraph; a curious one reads on for mechanics. Never force the mechanics on everyone.

## Step 4 — Right-size and make it navigable

- As short as complete. Cut throat-clearing and summary-of-summary.
- Provide the background the reader needs, but mark skippable context (`(skip if you know X)`) so those who have it jump past.
- For multiple items, number them (#1, #2, …) so they are referenceable in reply.

## Format defaults by artifact

- **PR / MR description**: follow the repo's PR template if one exists. In this Shopware repo, use the `pr-create` skill (the repo's template is required, not a generic one). Lead with what changes and why, for a reviewer; put deep mechanics lower.
- **Commit message**: conventional message with scope; subject = the change, body = the *why*, not the how.
- **Code-review / issue comment**: state the point first, then just enough code/context to act. Number multiple points.
- **Release / upgrade note**: write for the affected external party (extension author, operator, theme dev). In this repo, use the `shopware-release-docs` skill.
