"""Build the Tech Weekly deck on top of master-2026.pptx (its masters, layouts and theme)."""
import copy
import sys

from lxml import etree
from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_CONNECTOR, MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.oxml.ns import qn
from pptx.util import Emu, Inches, Pt

SRC = "/Users/g.weiermann/Documents/Presentations/master-2026.pptx"
OUT = sys.argv[1]  # example deck: Tech Weekly 2026-11; copy the helpers, replace the slides

INK = RGBColor(0x11, 0x15, 0x1E)
MUTED = RGBColor(0x5B, 0x63, 0x73)
BLUE = RGBColor(0x00, 0x69, 0xFC)
BLUE_TINT = RGBColor(0xE6, 0xF0, 0xFF)
LINE = RGBColor(0xD5, 0xDC, 0xE8)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)
HEAD = "+mj-lt"
TEXT = "+mn-lt"

prs = Presentation(SRC)

# Drop the template's example slides; keep masters, layouts and theme.
sld_ids = prs.slides._sldIdLst
for sld_id in list(sld_ids):
    prs.part.drop_rel(sld_id.rId)
    sld_ids.remove(sld_id)

LIGHT, DARK, BRAND = prs.slide_masters[0], prs.slide_masters[1], prs.slide_masters[2]


def layout(master, name):
    return next(l for l in master.slide_layouts if l.name == name)


def text(slide, x, y, w, h, paragraphs, size=16, color=INK, bold=False, font=TEXT,
         align=PP_ALIGN.LEFT, anchor=MSO_ANCHOR.TOP):
    """Text box; paragraphs is a list of str or (str, overrides) tuples."""
    box = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    tf = box.text_frame
    tf.word_wrap = True
    tf.vertical_anchor = anchor
    tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
    for i, item in enumerate(paragraphs):
        content, o = (item, {}) if isinstance(item, str) else item
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = o.get("align", align)
        if i:
            p.space_before = Pt(o.get("gap", 6))
        r = p.add_run()
        r.text = content
        f = r.font
        f.size = Pt(o.get("size", size))
        f.bold = o.get("bold", bold)
        f.name = o.get("font", font)
        f.color.rgb = o.get("color", color)
    return box


def card(slide, x, y, w, h, fill=WHITE, line=None, radius=0.12, shape=MSO_SHAPE.ROUNDED_RECTANGLE):
    s = slide.shapes.add_shape(shape, Inches(x), Inches(y), Inches(w), Inches(h))
    if shape == MSO_SHAPE.ROUNDED_RECTANGLE:
        s.adjustments[0] = radius
    s.fill.solid()
    s.fill.fore_color.rgb = fill
    if line is None:
        s.line.fill.background()
    else:
        s.line.color.rgb = line
        s.line.width = Pt(1)
    s.shadow.inherit = False
    s.text_frame.text = ""
    return s


def arrow(slide, x1, y1, x2, y2, color=BLUE, width=2, head=True):
    c = slide.shapes.add_connector(MSO_CONNECTOR.STRAIGHT, Inches(x1), Inches(y1), Inches(x2), Inches(y2))
    c.line.color.rgb = color
    c.line.width = Pt(width)
    if head:
        ln = c.line._get_or_add_ln()
        tail = etree.SubElement(ln, qn("a:tailEnd"))
        tail.set("type", "triangle")
        tail.set("w", "med")
        tail.set("len", "med")
    return c


def titled(title_text):
    s = prs.slides.add_slide(layout(LIGHT, "Title Only"))
    s.shapes.title.text = title_text
    return s


def section(title_text, tag=None):
    s = prs.slides.add_slide(layout(BRAND, "Section Title 1"))
    s.shapes.title.text = title_text
    s.shapes.title.text_frame.paragraphs[0].alignment = PP_ALIGN.CENTER
    if tag:
        card(s, 5.72, 2.75, 1.9, 0.42, fill=WHITE, radius=0.5)
        text(s, 5.72, 2.75, 1.9, 0.42, [tag], size=14, bold=True, color=BLUE, font=HEAD,
             align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)
    return s


def node(slide, x, y, w, h, head, sub=None, fill=WHITE, ink=INK, sub_ink=MUTED, line=None, size=20):
    card(slide, x, y, w, h, fill=fill, line=line)
    paras = [(head, {"size": size, "bold": True, "font": HEAD, "color": ink})]
    if sub:
        paras.append((sub, {"size": 14, "color": sub_ink, "gap": 4}))
    text(slide, x + 0.2, y, w - 0.4, h, paras, align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)


# 1 Cover
s = prs.slides.add_slide(layout(BRAND, "Title Slide"))
s.shapes.title.text = "Tech Weekly"
s.placeholders[1].text = "Working with agents, from one PR to the whole setup"

# 2 Section
section("Everyday skills")

# 3 Babysitting PRs
s = titled("Babysitting PRs")
items = [
    ("1", "Keep it current", "Merge trunk in, fix lint and CI, rerun flakes."),
    ("2", "Get it merged", "Queue it once it's green and approved."),
    ("3", "One session for all PRs", "Other sessions hand their PRs to it."),
]
for i, (num, head, body) in enumerate(items):
    y = 2.05 + i * 1.5
    text(s, 0.76, y, 0.8, 1.0, [num], size=54, bold=True, color=BLUE, font=HEAD)
    text(s, 1.65, y + 0.12, 5.2, 1.2, [(head, {"size": 22, "bold": True, "font": HEAD}),
                                      (body, {"size": 16, "color": MUTED})])
# visual: many PRs, one babysitter
hub_x, hub_y, r = 10.55, 4.15, 0.95
prs_y = [2.15, 3.35, 4.55, 5.75]
for i, py in enumerate(prs_y):
    card(s, 7.35, py, 1.75, 0.6, radius=0.5, line=LINE)
    text(s, 7.35, py, 1.75, 0.6, [f"PR #{['21805', '22946', '23095', '23163'][i]}"], size=14, bold=True,
         font=HEAD, align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)
    arrow(s, 9.15, py + 0.3, hub_x - r + 0.05, hub_y + (py + 0.3 - hub_y) * 0.35, color=LINE, width=1.5)
card(s, hub_x - r, hub_y - r, 2 * r, 2 * r, fill=BLUE, shape=MSO_SHAPE.OVAL)
text(s, hub_x - r, hub_y - r, 2 * r, 2 * r, ["one", ("session", {"gap": 0})], size=18, bold=True,
     color=WHITE, font=HEAD, align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)

# 4 Review, then post
s = titled("Review, then post")
y, h = 3.05, 1.6
node(s, 0.76, y, 1.9, h, "PR")
arrow(s, 2.71, y + h / 2, 3.21, y + h / 2)
node(s, 3.26, y, 3.3, h, "pr-review", "find, reproduce, report")
arrow(s, 6.61, y + h / 2, 7.11, y + h / 2)
node(s, 7.16, y, 3.3, h, "post-findings", "pending review on GitHub")
arrow(s, 10.51, y + h / 2, 11.01, y + h / 2)
node(s, 11.06, y, 1.5, h, "You", "submit", fill=BLUE, ink=WHITE, sub_ink=WHITE)
text(s, 0.76, 5.45, 11.8, 0.9, ["Each finding is reproduced on a running instance.",
                                 ("You decide what gets posted.", {"gap": 2})],
     size=18, color=MUTED, align=PP_ALIGN.CENTER)

# 5 Section
section("The bigger picture")

# 6 One home repo
s = titled("One home repo")
cx, cy = 6.67, 4.3
spokes = [
    (1.4, 2.2, "Repos", "shopware, meteor, commercial …"),
    (9.25, 2.2, "Instances", "shopware-1, shopware-2"),
    (0.76, 4.0, "Skills", None),
    (9.9, 4.0, "Docs", None),
    (5.32, 5.85, "Tooling", None),
]
for x, y, head, sub in spokes:
    arrow(s, cx, cy, x + 1.35, y + 0.5, color=LINE, width=1.5, head=False)
card(s, cx - 1.6, cy - 0.65, 3.2, 1.3, fill=BLUE)
text(s, cx - 1.6, cy - 0.65, 3.2, 1.3, ["shopware-home"], size=24, bold=True, color=WHITE, font=HEAD,
     align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)
for x, y, head, sub in spokes:
    node(s, x, y, 2.7, 1.0, head, sub, line=LINE, size=18)

# 7 Where skills live
s = titled("Where skills live")
sources = [("shopware-home/skills", "Shopware"), ("general/skills", "generic"), ("repo skills", "ship with each repo")]
for i, (head, sub) in enumerate(sources):
    node(s, 0.76, 2.1 + i * 1.45, 3.3, 1.15, head, sub, line=LINE, size=18)
    arrow(s, 4.11, 2.675 + i * 1.45, 5.05, 4.13, color=LINE, width=1.5)
node(s, 5.1, 3.55, 3.0, 1.15, "~/.agents/skills", None, fill=BLUE, ink=WHITE, sub_ink=WHITE, size=18)
for i, tool in enumerate(["Claude Code", "Codex"]):
    arrow(s, 8.15, 4.13, 9.3, 3.075 + i * 2.1)
    node(s, 9.35, 2.5 + i * 2.1, 3.2, 1.15, tool, line=LINE)

# 8 Starting an agent
s = titled("Starting an agent")
steps = [("1", "Open a session", "in the home repo"),
         ("2", "Read the map", "repos, instances, skills"),
         ("3", "Make a worktree", "where the work is")]
for i, (num, head, sub) in enumerate(steps):
    x = 0.76 + i * 4.1
    card(s, x, 2.3, 3.6, 3.4, line=LINE)
    text(s, x + 0.35, 2.55, 2.9, 1.2, [num], size=54, bold=True, color=BLUE, font=HEAD)
    text(s, x + 0.35, 3.95, 2.9, 1.5, [(head, {"size": 22, "bold": True, "font": HEAD}),
                                      (sub, {"size": 16, "color": MUTED})])
    if i < 2:
        arrow(s, x + 3.65, 4.0, x + 4.05, 4.0)

# 9 Worktrees on shared instances
s = titled("Worktrees on shared instances")
card(s, 0.76, 2.0, 6.9, 4.4, fill=BLUE_TINT, radius=0.06)
text(s, 1.1, 2.25, 6.2, 0.9, [("shopware-1", {"size": 22, "bold": True, "font": HEAD}),
                              ("trunk + Docker stack", {"size": 14, "color": MUTED, "gap": 2})])
for i, wt in enumerate(["fix-22946", "review-23163", "feature-x"]):
    node(s, 1.1, 3.35 + i * 0.95, 3.4, 0.75, wt, line=LINE, size=16)
    arrow(s, 4.55, 3.725 + i * 0.95, 5.15, 4.7, color=LINE, width=1.5)
node(s, 5.2, 4.2, 2.1, 1.0, "attach", fill=BLUE, ink=WHITE, size=18)
arrow(s, 7.35, 4.7, 8.25, 4.7)
card(s, 8.3, 3.0, 4.26, 3.4, fill=INK, radius=0.06)
text(s, 8.65, 3.3, 3.6, 2.9, [("READY", {"size": 24, "bold": True, "font": HEAD, "color": RGBColor(0x7F, 0xEF, 0x85)}),
                              ("jest", {"gap": 14}), "eslint", "phpunit", "own admin dev server"],
     size=18, color=WHITE)

# 10 Section
section("Context guard", tag="Experimental")

# 11 Three skills
s = titled("Three skills")
skills = [("Set up", "setup-context", "Asks you what the repo can't tell."),
          ("Audit", "audit-context", "Finds rules that work against the current model."),
          ("Learn", "mine-sessions", "Learns from last week's sessions.")]
for i, (verb, name, body) in enumerate(skills):
    x = 0.76 + i * 4.1
    card(s, x, 2.3, 3.6, 3.4, line=LINE)
    text(s, x + 0.35, 2.6, 2.9, 3.0, [(verb, {"size": 36, "bold": True, "font": HEAD, "color": BLUE}),
                                     (name, {"size": 16, "bold": True, "font": HEAD, "gap": 10}),
                                     (body, {"size": 16, "color": MUTED, "gap": 10})])

# 12 My rules on top of trunk
s = titled("My rules on top of trunk")
layers = [("Fragments", "rules I switch on and off", BLUE, WHITE, WHITE),
          ("Patches", "my edits, per section", BLUE_TINT, INK, MUTED),
          ("Trunk AGENTS.md", None, WHITE, INK, MUTED)]
for i, (head, sub, fill, ink, sub_ink) in enumerate(layers):
    node(s, 0.76, 2.1 + i * 1.3, 4.6, 1.1, head, sub, fill=fill, ink=ink, sub_ink=sub_ink,
         line=LINE if fill == WHITE else None, size=18)
arrow(s, 5.45, 3.75, 7.45, 3.75)
text(s, 5.45, 3.2, 2.0, 0.4, ["ctx build"], size=14, bold=True, color=BLUE, font=HEAD, align=PP_ALIGN.CENTER)
for i in range(3):
    off = (2 - i) * 0.18
    node(s, 7.6 + off, 2.75 + off, 4.4, 1.65, "every worktree" if i == 2 else "", line=LINE, size=18)
card(s, 0.76, 6.05, 11.8, 0.75, fill=INK, radius=0.5)
text(s, 0.76, 6.05, 11.8, 0.75, ["The guard asks before a trunk change takes effect."], size=18, bold=True,
     color=WHITE, font=HEAD, align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)

# 13 End
s = prs.slides.add_slide(layout(BRAND, "End"))
s.shapes.title.text = "Thanks"
for ph in s.placeholders:
    if ph.placeholder_format.idx == 13:
        ph.text = "Questions?"
    elif ph.placeholder_format.idx == 1:
        ph._element.getparent().remove(ph._element)

prs.save(OUT)
print("saved", OUT, len(prs.slides), "slides")
