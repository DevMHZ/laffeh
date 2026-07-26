#!/usr/bin/env python3
"""Builds legal/index.html — the single hostable page — from the Markdown sources.

The .md files are the source of truth. Edit those, re-run this, upload the HTML.

    python3 legal/build.py

Deliberately dependency-free (no pandoc, no python-markdown) so this keeps
working on any machine. It understands only the Markdown subset these documents
actually use: headings, tables, bullet lists, blockquotes, horizontal rules,
bold, and inline code.
"""

from __future__ import annotations

import html
import json
import re
from pathlib import Path

HERE = Path(__file__).parent

DOCS = ["privacy-policy", "terms-of-service", "account-deletion"]
LANGS = ["en", "ar", "fr"]

LANG_NAMES = {"en": "English", "ar": "العربية", "fr": "Français"}
DOC_NAMES = {
    "en": {
        "privacy-policy": "Privacy Policy",
        "terms-of-service": "Terms of Service",
        "account-deletion": "Delete Account",
    },
    "ar": {
        "privacy-policy": "سياسة الخصوصية",
        "terms-of-service": "شروط الاستخدام",
        "account-deletion": "حذف الحساب",
    },
    "fr": {
        "privacy-policy": "Confidentialité",
        "terms-of-service": "Conditions",
        "account-deletion": "Supprimer le compte",
    },
}


# ── inline ──────────────────────────────────────────────────────────────────

def _inline(text: str) -> str:
    """Escape, then apply inline markup. Code spans are stashed first so their
    contents never get re-processed (e.g. `[[NAME]]` must stay literal)."""
    stash: list[str] = []

    def keep(match: re.Match[str]) -> str:
        stash.append(html.escape(match.group(1)))
        return f"\x00{len(stash) - 1}\x00"

    text = re.sub(r"`([^`]+)`", keep, text)
    text = html.escape(text)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', text)
    # Bare URLs left in the prose (contact links, service hosts).
    text = re.sub(
        r"(?<![\">=])(https?://[^\s<),]+)", r'<a href="\1">\1</a>', text
    )
    return re.sub(r"\x00(\d+)\x00", lambda m: f"<code>{stash[int(m.group(1))]}</code>", text)


# ── blocks ──────────────────────────────────────────────────────────────────

def _table(lines: list[str]) -> str:
    rows = [[c.strip() for c in ln.strip().strip("|").split("|")] for ln in lines]
    # Row 1 is the header, row 2 is the |---|---| separator.
    body = rows[2:] if len(rows) > 2 else []
    head = "".join(f"<th>{_inline(c)}</th>" for c in rows[0])
    out = [f"<table><thead><tr>{head}</tr></thead><tbody>"]
    for row in body:
        cells = "".join(f"<td>{_inline(c)}</td>" for c in row)
        out.append(f"<tr>{cells}</tr>")
    out.append("</tbody></table>")
    return "".join(out)


ORDERED = re.compile(r"^\d+\.\s+")


def _list(block: str, ordered: bool = False) -> str:
    items: list[str] = []
    for line in block.split("\n"):
        stripped = line.lstrip()
        marker = ORDERED.match(stripped) if ordered else None
        if ordered and marker:
            items.append(stripped[marker.end():].strip())
        elif not ordered and stripped.startswith("- "):
            items.append(stripped[2:].strip())
        elif items:
            items[-1] += " " + line.strip()  # wrapped continuation line
    tag = "ol" if ordered else "ul"
    body = "".join(f"<li>{_inline(i)}</li>" for i in items)
    return f"<{tag}>{body}</{tag}>"


def render(md: str) -> str:
    out: list[str] = []
    for block in re.split(r"\n\s*\n", md.strip()):
        block = block.strip("\n")
        if not block.strip():
            continue
        first = block.lstrip()

        if set(block.strip()) == {"-"} and len(block.strip()) >= 3:
            out.append("<hr>")
        elif first.startswith("# "):
            out.append(f"<h1>{_inline(first[2:].strip())}</h1>")
        elif first.startswith("## "):
            out.append(f"<h2>{_inline(first[3:].strip())}</h2>")
        elif first.startswith("### "):
            out.append(f"<h3>{_inline(first[4:].strip())}</h3>")
        elif first.startswith(">"):
            inner = " ".join(
                ln.lstrip().lstrip(">").strip() for ln in block.split("\n")
            )
            out.append(f"<blockquote>{_inline(inner)}</blockquote>")
        elif first.startswith("|"):
            out.append(_table([ln for ln in block.split("\n") if ln.strip()]))
        elif first.startswith("- "):
            out.append(_list(block))
        elif ORDERED.match(first):
            out.append(_list(block, ordered=True))
        else:
            # A hard-wrapped paragraph: soft newlines re-flow, but a line
            # ending in two spaces is an explicit break (standard Markdown).
            # Each segment is escaped on its own — inserting the <br> first
            # would get it escaped along with the text.
            para = "<br>".join(
                _inline(" ".join(ln.strip() for ln in seg.split("\n")))
                for seg in re.split(r"  \n", block)
            )
            out.append(f"<p>{para}</p>")
    return "\n".join(out)


# ── page ────────────────────────────────────────────────────────────────────

CSS = """
*,*::before,*::after{box-sizing:border-box}
:root{
  --bg:#ffffff; --fg:#1a1d21; --muted:#5c636b; --line:#e3e6ea;
  --accent:#0b6b5a; --card:#f6f8f9; --warn-bg:#fff8e6; --warn-line:#e8c86a;
}
@media (prefers-color-scheme:dark){
  :root{--bg:#14171a; --fg:#e8eaed; --muted:#9aa2ab; --line:#2a2f35;
        --accent:#4fd1b3; --card:#1c2126; --warn-bg:#2a2415; --warn-line:#6b5a24;}
}
:root[data-theme="dark"]{--bg:#14171a; --fg:#e8eaed; --muted:#9aa2ab; --line:#2a2f35;
  --accent:#4fd1b3; --card:#1c2126; --warn-bg:#2a2415; --warn-line:#6b5a24;}
:root[data-theme="light"]{--bg:#ffffff; --fg:#1a1d21; --muted:#5c636b; --line:#e3e6ea;
  --accent:#0b6b5a; --card:#f6f8f9; --warn-bg:#fff8e6; --warn-line:#e8c86a;}
body{margin:0;background:var(--bg);color:var(--fg);
  font:16px/1.7 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,"Helvetica Neue",Arial,sans-serif;
  -webkit-text-size-adjust:100%}
.wrap{max-width:820px;margin:0 auto;padding:28px 20px 80px}
nav{display:flex;flex-wrap:wrap;gap:8px;align-items:center;
  padding-bottom:18px;margin-bottom:26px;border-bottom:1px solid var(--line)}
nav .sp{flex:1 1 auto;min-width:8px}
button{font:inherit;font-size:14px;padding:7px 13px;border-radius:999px;cursor:pointer;
  border:1px solid var(--line);background:transparent;color:var(--muted);transition:.15s}
button:hover{border-color:var(--accent);color:var(--fg)}
button[aria-pressed="true"]{background:var(--accent);border-color:var(--accent);color:#fff}
@media (prefers-color-scheme:dark){button[aria-pressed="true"]{color:#0e1417}}
:root[data-theme="dark"] button[aria-pressed="true"]{color:#0e1417}
h1{font-size:1.75rem;line-height:1.3;margin:.2em 0 .6em}
h2{font-size:1.2rem;margin:2.2em 0 .5em;padding-top:.2em}
h3{font-size:1.02rem;margin:1.6em 0 .4em;color:var(--muted)}
p{margin:0 0 1em}
ul{margin:0 0 1em;padding-inline-start:1.3em}
li{margin-bottom:.45em}
a{color:var(--accent)}
code{background:var(--card);padding:.12em .4em;border-radius:5px;
  font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.88em}
hr{border:0;border-top:1px solid var(--line);margin:2.2em 0}
blockquote{margin:0 0 1.4em;padding:12px 16px;border-radius:10px;
  background:var(--warn-bg);border:1px solid var(--warn-line);color:var(--fg)}
blockquote code{background:rgba(0,0,0,.07)}
.tw{overflow-x:auto;-webkit-overflow-scrolling:touch;margin:0 0 1.4em}
table{border-collapse:collapse;width:100%;min-width:420px;font-size:.94rem}
th,td{border:1px solid var(--line);padding:9px 12px;text-align:start;vertical-align:top}
th{background:var(--card);font-weight:600}
section{display:none}
section.on{display:block}
[dir="rtl"]{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Tahoma,Arial,sans-serif}
"""

JS = """
(function(){
  var lang='en', doc='privacy-policy';
  function show(){
    document.querySelectorAll('section').forEach(function(s){
      s.classList.toggle('on', s.id===doc+'-'+lang);
    });
    document.querySelectorAll('[data-lang]').forEach(function(b){
      b.setAttribute('aria-pressed', String(b.dataset.lang===lang));
    });
    document.querySelectorAll('[data-doc]').forEach(function(b){
      b.setAttribute('aria-pressed', String(b.dataset.doc===doc));
      // Names ride in one JSON attribute: HTML lowercases attribute names, so
      // per-language attributes like data-nameEN are unreadable as dataset.nameEN.
      b.textContent = JSON.parse(b.dataset.names)[lang];
    });
    var rtl = lang==='ar';
    document.documentElement.lang = lang;
    document.documentElement.dir = rtl ? 'rtl' : 'ltr';
    if (history.replaceState) history.replaceState(null,'','#'+doc+'/'+lang);
    window.scrollTo(0,0);
  }
  document.addEventListener('click', function(e){
    var b = e.target.closest('button'); if(!b) return;
    if (b.dataset.lang) lang = b.dataset.lang;
    if (b.dataset.doc)  doc  = b.dataset.doc;
    show();
  });
  var m = /^#([a-z-]+)\\/([a-z]{2})$/.exec(location.hash||'');
  if (m) { doc = m[1]; lang = m[2]; }
  show();
})();
"""


def build() -> Path:
    nav = ['<nav>']
    for d in DOCS:
        names = html.escape(
            json.dumps({l: DOC_NAMES[l][d] for l in LANGS}, ensure_ascii=False),
            quote=True,
        )
        nav.append(
            f'<button data-doc="{d}" data-names="{names}">'
            f'{html.escape(DOC_NAMES["en"][d])}</button>'
        )
    nav.append('<span class="sp"></span>')
    for l in LANGS:
        nav.append(f'<button data-lang="{l}">{LANG_NAMES[l]}</button>')
    nav.append("</nav>")

    sections = []
    for d in DOCS:
        for l in LANGS:
            src = HERE / f"{d}.{l}.md"
            if not src.exists():
                raise SystemExit(f"missing source: {src}")
            body = render(src.read_text(encoding="utf-8"))
            # Tables need their own scroll container so the page never scrolls
            # sideways on a phone.
            body = body.replace("<table>", '<div class="tw"><table>')
            body = body.replace("</table>", "</table></div>")
            sections.append(
                f'<section id="{d}-{l}" lang="{l}" '
                f'dir="{"rtl" if l == "ar" else "ltr"}">{body}</section>'
            )

    page = (
        "<!doctype html>\n<html lang=\"en\">\n<head>\n"
        '<meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width,initial-scale=1">\n'
        "<title>Laffah — Legal</title>\n"
        f"<style>{CSS}</style>\n</head>\n<body>\n"
        f'<div class="wrap">{"".join(nav)}\n{"".join(sections)}</div>\n'
        f"<script>{JS}</script>\n</body>\n</html>\n"
    )

    out = HERE / "index.html"
    out.write_text(page, encoding="utf-8")
    return out


if __name__ == "__main__":
    path = build()
    print(f"wrote {path} ({path.stat().st_size:,} bytes)")
