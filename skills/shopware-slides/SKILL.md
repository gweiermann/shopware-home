---
name: shopware-slides
description: Build a PowerPoint deck on the Shopware 2026 master template - a short, visual talk that shares the vision, not the details. Use when asked for slides, a deck or a presentation.
---

# Shopware slides

Copy `~/Documents/Presentations/master-2026.pptx` and build the deck on it, so it keeps the masters, layouts, colours and fonts.
Save it next to the master in `~/Documents/Presentations/`.

Keep it short. Each slide makes one point, and a visual carries it: a flow, a hub, numbered steps, a stack.
Share the vision; nobody in the room needs the details.
Then review every slide again and keep removing text until only the point is left.
Word the remaining text with the `humanizer` skill.

## What helped last time

- `python-pptx` in a scratchpad venv does the job; the system Python lacks it.
  [example-build.py](example-build.py) has the helpers (drop the template's example slides, text, cards, arrows) and a full deck to borrow layouts from.
- The template has three masters: light (0), dark (1) and brand blue (2).
  The blue master's `Title Slide`, `Section Title 1` and `End` make good cover, section and closing slides; the light `Title Only` layout fits diagram slides.
- Theme fonts come through as `+mj-lt` (headline) and `+mn-lt` (text). The palette is ink `11151E`, blue `0069FC`, background `F7FAFF`, with white rounded cards on top.
- Look at every slide before you hand it over. [render.sh](render.sh) exports PNGs through Keynote, because PowerPoint's AppleScript export writes nothing from a terminal; it takes a minute or two.
  [sheet.py](sheet.py) puts them on one contact sheet.
- Short labels in boxes read better than sentences; a caption under a diagram is often the first thing you can delete.
