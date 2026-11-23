#!/usr/bin/env python3
"""Render UX.md into index.html: one section per feature, each with its video.

UX.md format:

    ---
    title: Le nouveau tableau de bord, fonctionnalité par fonctionnalité
    eyebrow: Superdocu · PR #2354
    pr: https://github.com/OWNER/REPO/pull/2354
    lang: fr
    ---
    Intro paragraph, shown under the title.

    ## Bandeau d'accueil {#01-bandeau}
    > One sentence: what this feature is for.
    - What the video shows, one bullet per thing seen.
    ### À regarder
    - What a reviewer should check.

    ## Sur mobile {#09-mobile .portrait}
    ...

    ## Non filmé
    - A section without {#id} has no video: notes at the end of the page.

A feature `{#slug}` plays `videos/<slug>.mp4` with `videos/<slug>.jpg` as
poster. `.portrait` centres a phone-sized video. Exit 1 on any warning.
"""
import html
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent
NBSP = " "


def parse_front_matter(text):
    match = re.match(r"---\n(.*?)\n---\n", text, re.S)
    if not match:
        sys.exit("UX.md must start with a --- front matter block")
    meta = {}
    for line in match.group(1).splitlines():
        key, _, value = line.partition(":")
        meta[key.strip()] = value.strip()
    return meta, text[match.end():]


def parse_sections(body):
    intro, *chunks = re.split(r"^## ", body, flags=re.M)
    sections = []
    for chunk in chunks:
        heading, _, rest = chunk.partition("\n")
        attrs = re.search(r"\{([^}]*)\}\s*$", heading)
        title = heading[: attrs.start()].strip() if attrs else heading.strip()
        slug, classes = None, []
        if attrs:
            for token in attrs.group(1).split():
                if token.startswith("#"):
                    slug = token[1:]
                elif token.startswith("."):
                    classes.append(token[1:])
        sections.append({"title": title, "slug": slug, "classes": classes, "body": rest})
    return intro.strip(), sections


def typography(text, lang):
    text = html.escape(text, quote=False)
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"\[([^\]]+)\]\((https?://[^)]+)\)", r'<a href="\2">\1</a>', text)
    if lang == "fr":
        for before, after in (("« ", "«" + NBSP), (" »", NBSP + "»"), (" :", NBSP + ":"),
                              (" ;", NBSP + ";"), (" ?", NBSP + "?"), (" !", NBSP + "!")):
            text = text.replace(before, after)
    return text


def render_blocks(body, lang):
    out, bullets, check = [], [], None

    def flush():
        nonlocal bullets
        if bullets:
            out.append("<ul>" + "".join(f"<li>{typography(b, lang)}</li>" for b in bullets) + "</ul>")
            bullets = []

    for line in body.splitlines():
        if line.startswith("- "):
            bullets.append(line[2:].strip())
        elif line.startswith("  ") and bullets:
            bullets[-1] += " " + line.strip()
        elif line.startswith("### "):
            flush()
            if check is not None:
                out.append("</div>")
            out.append(f'<div class="check"><h4>{typography(line[4:].strip(), lang)}</h4>')
            check = True
        elif line.startswith("> "):
            flush()
            out.append(f'<p class="pitch">{typography(line[2:].strip(), lang)}</p>')
        elif line.strip():
            flush()
            out.append(f"<p>{typography(line.strip(), lang)}</p>")
        else:
            flush()
    flush()
    if check is not None:
        out.append("</div>")
    return "\n".join(out)


def render(meta, intro, sections):
    lang = meta.get("lang", "fr")
    features = [s for s in sections if s["slug"]]
    notes = [s for s in sections if not s["slug"]]
    toc = "".join(f'<li><a href="#{s["slug"]}">{typography(s["title"], lang)}</a></li>' for s in features)
    blocks = []
    for index, section in enumerate(features, 1):
        slug = section["slug"]
        portrait = " portrait" if "portrait" in section["classes"] else ""
        blocks.append(f"""
<section class="feature" id="{slug}">
  <div class="media{portrait}">
    <video controls preload="none" playsinline poster="videos/{slug}.jpg">
      <source src="videos/{slug}.mp4" type="video/mp4">
    </video>
  </div>
  <div class="text">
    <p class="num">{index:02d}</p>
    <h2>{typography(section['title'], lang)}</h2>
    {render_blocks(section['body'], lang)}
  </div>
</section>""")
    notes_html = "".join(f"<h2>{typography(n['title'], lang)}</h2>{render_blocks(n['body'], lang)}" for n in notes)
    eyebrow = typography(meta.get("eyebrow", ""), lang)
    if meta.get("pr"):
        eyebrow = f'<a href="{html.escape(meta["pr"])}">{eyebrow or "PR"}</a>'
    return f"""<!doctype html>
<html lang="{lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>{html.escape(meta.get('title', 'Guide UX'))}</title>
<link rel="stylesheet" href="style.css">
</head>
<body>
<header class="hero">
  <div class="wrap">
    <p class="eyebrow">{eyebrow}</p>
    <h1>{typography(meta.get('title', ''), lang)}</h1>
    <p class="lead">{typography(intro, lang)}</p>
  </div>
</header>
<main class="wrap">
  <nav class="toc"><ol>{toc}</ol></nav>
  {''.join(blocks)}
  {f'<section class="notes">{notes_html}</section>' if notes else ''}
</main>
</body>
</html>
"""


def check(sections):
    warnings = []
    slugs = [s["slug"] for s in sections if s["slug"]]
    if len(set(slugs)) != len(slugs):
        warnings.append("duplicate feature id")
    for slug in slugs:
        for ext in ("mp4", "jpg"):
            if not (ROOT / "videos" / f"{slug}.{ext}").exists():
                warnings.append(f"missing videos/{slug}.{ext}")
    for video in sorted((ROOT / "videos").glob("*.mp4")):
        if video.stem not in slugs:
            warnings.append(f"videos/{video.name} is not used by any section")
    return warnings


def main():
    meta, body = parse_front_matter((ROOT / "UX.md").read_text())
    intro, sections = parse_sections(body)
    (ROOT / "index.html").write_text(render(meta, intro, sections))
    warnings = check(sections)
    for warning in warnings:
        print("WARNING", warning)
    print(f"{len(warnings)} warning(s)")
    sys.exit(1 if warnings else 0)


main()
