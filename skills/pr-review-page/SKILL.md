---
name: pr-review-page
description: Turn a pr-review report into a static HTML page where each finding opens its own subpage with reproduction, evidence and screenshots. Use when asked for the review as a page, an HTML report, or something shareable to open in the browser.
---

# PR review page

The page is the chat report from `pr-review`, laid out for the browser.
It keeps the chat's calm look: plain headings, monospace text blocks, short prose.
What the page adds is depth on demand: a reader scans the summaries and opens only the finding they care about, on a subpage that holds everything backing it.
Subpages live in the same file and show through the URL fragment (`#finding-1`), so each finding is linkable and the browser's back button returns to the report.

## 1. Get the report

- **The report is already in this conversation** for the same PR and head commit: use it as is, with its screenshot paths.
- **Otherwise** start a background agent that runs the `pr-review` skill on the target and returns the full markdown report plus the absolute path of every screenshot.
  Work on the page skeleton meanwhile, and fill it once the report arrives.

Done when you hold the whole report: every section `pr-review` writes, and every screenshot path it names exists on disk.

## 2. Build the page

Copy [`template.html`](template.html) to `<scratchpad>/pr-<number>-review.html` and fill it.
The template carries the styling, the dark palette of the Claude Code chat, and one example of every block; replace the examples, keep the structure.

The page is written to be published, so every reader sees the same page from anywhere.
Carry over what holds for them: the PR, the code, the findings and their proof.
Leave the review's own environment in the chat: its URLs, ports, logins, local paths and the "Try it yourself" section.

Map the report onto it:

| Report section | On the page |
|---|---|
| What's new | Paragraph, always visible |
| Impact and blast radius | List, always visible |
| Findings in this PR | One `<a class="finding-link">` per finding, pointing at its subpage |
| Implementation details | One `<pre class="block">` per shift, always visible |
| Details, screenshots, appendix | Moved into their finding's `<section class="subpage">` |
| Before merge | List, always visible |
| Out of scope | `<details>` section, closed |

A finding's link is the same text block the chat shows: number, title, priority, confidence, the "When …" bullets and the suggestion.
Its subpage repeats that block on top, then holds everything that backs it, in reading order: reproduction steps, evidence snippet with the clickable `file:line` link to GitHub at the PR head, the suggested fix as code, then its screenshots with their step captions.
A reader on one subpage needs nothing from elsewhere on the page.

Accessibility is part of done:

- Every screenshot has `alt` text that says what the red marker shows.
- Priority and confidence are spelled out in text; the colour only repeats it.
- Code and links keep the template's colours, which hold at least 4.5:1 contrast in both themes.

## 3. Inline and deliver

Write `<img src>` as the absolute screenshot path, then make the file self-contained:

```bash
python3 <this skill's directory>/inline-images.py <scratchpad>/pr-<number>-review.html
```

Send it with `SendUserFile` (`display: "render"`) and link its absolute path in the reply.
Done when the file opens with every image shown and no request leaving the file.
