#!/usr/bin/env python3
"""Replace every <img src="/absolute/path.png"> in an HTML file with a data URI, in place."""
import base64
import mimetypes
import pathlib
import re
import sys

page = pathlib.Path(sys.argv[1])
html = page.read_text(encoding="utf-8")
missing = []


def inline(match: re.Match) -> str:
    path = pathlib.Path(match.group(2))
    if not path.is_file():
        missing.append(str(path))
        return match.group(0)
    mime = mimetypes.guess_type(path.name)[0] or "image/png"
    data = base64.b64encode(path.read_bytes()).decode("ascii")
    return f'{match.group(1)}data:{mime};base64,{data}"'


html = re.sub(r'(<img[^>]*?\ssrc=")(/[^"]+)"', inline, html)
page.write_text(html, encoding="utf-8")

if missing:
    sys.exit("Missing images:\n" + "\n".join(missing))
print(f"Inlined images into {page}")
