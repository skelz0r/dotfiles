#!/usr/bin/env python3
"""Builds index.html: variants of one screen, drawn with the project's compiled CSS.

Edit this file only, then run `python3 build.py`. It copies the project's
compiled CSS and fonts next to the page, writes index.html and fails when a
class used in the page exists neither in the compiled CSS nor in PAGE_STYLE,
unless listed in UNSTYLED (copied from the real markup, styled nowhere).
"""

import argparse
import html.parser
import pathlib
import re
import shutil
import sys

ROOT = pathlib.Path(__file__).parent
PROJECT = pathlib.Path.home() / "work/<project>"

CSS_SOURCES = ["app/assets/builds/application.css"]
URL_REWRITES = [("url(/fonts/", "url(fonts/")]
ASSET_DIRS = [("public/fonts", "fonts", "*.woff2")]
ICON_PATH = "app/assets/svg/icons/heroicons/{variant}/{name}.svg"
UNSTYLED = set()

LANG = "fr"
TITLE = "<Écran> : <ce qui change>"
INTRO = """<p>Le problème en deux phrases. Écrans dessinés avec le CSS et les icônes de l'app,
pas branchés : <ce qui est fictif>.</p>"""


def icon(name, cls="size-4", variant="outline"):
    svg = (PROJECT / ICON_PATH.format(variant=variant, name=name)).read_text().strip()
    return re.sub(r"<svg", f'<svg class="{cls}" aria-hidden="true"', svg, count=1)


def header(actions):
    return f"""
<div class="py-4 flex items-center">
  <h1 class="flex-1 text-2xl font-semibold">Écran</h1>
  <div class="flex gap-2 items-center">{actions}</div>
</div>"""


def screen(head, body=""):
    return f"""
<div class="mock">
  {head}
  <div class="bg-white rounded-xl border p-4">{body}</div>
</div>"""


PRIMARY = '<a class="btn primary">Action principale</a>'
SECONDARY = '<a class="btn secondary">Action rare</a>'

VARIANTS = [
    {
        "id": "actuel",
        "title": "Actuel",
        "pitch": "Ce que montre l'app aujourd'hui.",
        "pros": [],
        "cons": ["Pourquoi on cherche autre chose."],
        "html": screen(header(SECONDARY + PRIMARY)),
    },
    {
        "id": "a",
        "title": "A · <nom court>",
        "pitch": "Une phrase : où va l'élément et pourquoi.",
        "pros": ["Ce que ça règle."],
        "cons": ["Ce que ça coûte."],
        "html": screen(header(PRIMARY), f'<a class="text-sm">{icon("trash")}Action rare</a>'),
    },
]

PAGE_STYLE = """
  body { margin: 0; background: #fff; }
  .page { max-width: 1240px; margin: 0 auto; padding: 40px 24px 80px; }
  .page > header h1 { font-size: 28px; font-weight: 700; margin: 0 0 8px; }
  .page > header p { font-size: 15px; max-width: 760px; margin: 0 0 12px; }
  .page nav.toc { display: flex; flex-wrap: wrap; gap: 8px; margin: 16px 0 8px; }
  .page nav.toc a { font-size: 13px; padding: 4px 12px; border-radius: 999px; border: 1px solid #e5e7eb; }
  .page section { margin-top: 56px; }
  .page section h2 { font-size: 20px; font-weight: 700; margin: 0 0 4px; }
  .page .pitch { font-size: 15px; margin: 0 0 8px; }
  .page .notes { display: flex; gap: 32px; font-size: 13px; margin-bottom: 14px; }
  .page .notes h3 { font-size: 12px; text-transform: uppercase; letter-spacing: .04em; margin: 0 0 2px; }
  .page .notes h3.good { color: #18753c; }
  .page .notes h3.bad { color: #b34000; }
  .page .notes ul { margin: 0; padding-left: 18px; list-style: disc; }
  .mock { padding: 8px 24px 24px; border-radius: 14px; border: 1px solid #e5e7eb; overflow-x: auto; }
  .mock a, .mock button { cursor: default; }
  @media (max-width: 700px) { .page .notes { flex-direction: column; gap: 8px; } .mock { padding: 8px 12px 16px; } }
"""

PAGE = """<!doctype html>
<html lang="__LANG__">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>__TITLE__</title>
<link rel="stylesheet" href="app.css">
<style>__STYLE__</style>
</head>
<body>
<main class="page">
<header>
  <h1>__TITLE__</h1>
  __INTRO__
  <nav class="toc">__TOC__</nav>
</header>
__SECTIONS__
</main>
</body>
</html>
"""


def variant(v):
    notes = ""
    for label, cls, items in (("Pour", "good", v["pros"]), ("Contre", "bad", v["cons"])):
        if items:
            lis = "".join(f"<li>{item}</li>" for item in items)
            notes += f'<div><h3 class="{cls}">{label}</h3><ul>{lis}</ul></div>'
    return f"""
<section id="{v["id"]}">
  <h2>{v["title"]}</h2>
  <p class="pitch">{v["pitch"]}</p>
  <div class="notes">{notes}</div>
  {v["html"]}
</section>"""


def copy_assets():
    css = "\n".join((PROJECT / source).read_text() for source in CSS_SOURCES)
    for old, new in URL_REWRITES:
        css = css.replace(old, new)
    (ROOT / "app.css").write_text(css)
    for source, dest, pattern in ASSET_DIRS:
        target = ROOT / dest
        target.mkdir(parents=True, exist_ok=True)
        for path in (PROJECT / source).glob(pattern):
            shutil.copy2(path, target / path.name)
    return css


def css_classes(css):
    return {re.sub(r"\\(.)", r"\1", name) for name in re.findall(r"\.((?:\\.|[\w-])+)", css)}


class ClassCollector(html.parser.HTMLParser):
    def __init__(self):
        super().__init__()
        self.used = set()

    def handle_starttag(self, tag, attrs):
        for key, value in attrs:
            if key == "class" and value:
                self.used.update(value.split())


def missing_classes(page, css):
    collector = ClassCollector()
    collector.feed(page)
    return sorted(collector.used - css_classes(css) - css_classes(PAGE_STYLE) - UNSTYLED)


def main():
    argparse.ArgumentParser(description=__doc__).parse_args()
    css = copy_assets()
    toc = "".join(f'<a href="#{v["id"]}">{v["title"]}</a>' for v in VARIANTS)
    sections = "".join(variant(v) for v in VARIANTS)
    page = PAGE
    for marker, value in (
        ("__LANG__", LANG),
        ("__TITLE__", TITLE),
        ("__STYLE__", PAGE_STYLE),
        ("__INTRO__", INTRO),
        ("__TOC__", toc),
        ("__SECTIONS__", sections),
    ):
        page = page.replace(marker, value)
    (ROOT / "index.html").write_text(page)
    missing = missing_classes(page, css)
    for name in missing:
        print(f"warning: class not in the compiled CSS nor PAGE_STYLE nor UNSTYLED: {name}", file=sys.stderr)
    print(f"{len(VARIANTS)} sections written, {len(missing)} warning(s)")
    sys.exit(1 if missing else 0)


main()
