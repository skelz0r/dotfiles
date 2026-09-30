#!/usr/bin/env python3
"""Builds index.html from GUIDE.md. Edit GUIDE.md, then run `python3 build.py`.

index.html is overwritten on each run: never edit it by hand. Requires pandoc
(3.x, for commonmark_x). `--check-urls` also fetches every external link.

GUIDE.md syntax, on top of CommonMark:
  front matter       title, repo (owner/name), sha (40 hex), plus optional kicker,
                     lang, pr, checkout (local clone used to verify links), footer
  <!-- tab: Name --> starts a tab; what comes before the first one is the intro
  gh:path#L10-L20    file at the pinned sha, verified against the local clone
  tree:path          directory at the pinned sha
  commit:abc1234     commit page, inside the PR when `pr` is set
  pr:                the pull request
  ::: callout        callout box (add .info, .good or .warning); a first
                     paragraph in bold becomes its title
  [503]{.status}     HTTP status badge; a table cell holding only a status gets one too
"""

import html
import pathlib
import re
import subprocess
import sys
import urllib.request

ROOT = pathlib.Path(__file__).parent
SOURCE = ROOT / "GUIDE.md"
OUTPUT = ROOT / "index.html"

LABELS = {
    "fr": {"tabs": "Sections du guide", "footer": "Guide de revue — liens figés sur le commit {sha}."},
    "en": {"tabs": "Guide sections", "footer": "Review guide — links pinned to commit {sha}."},
}

WARNINGS = []
TAB_MARKER = re.compile(r"<!-- tab: (.+?) -->")
SCHEME_LINK = re.compile(r"(\]\(|^\[[^\]]+\]:[ \t]*)(gh|tree|commit|pr):([^)\s]*)", re.M)
REF_DEFINITION = re.compile(r"^\[[^\]]+\]:[ \t]*\S+.*$", re.M)
UNPINNED = re.compile(r"https://github\.com/[^/\s]+/[^/\s]+/(?:blob|tree)/([^/\s)#]+)")
STATUS = r"[1-5]\d\d"


def warn(message):
    WARNINGS.append(message)


def front_matter(text):
    match = re.match(r"---\n(.*?)\n---\n", text, re.S)
    if not match:
        sys.exit("GUIDE.md must start with a --- front matter block")
    meta = {}
    for line in match.group(1).splitlines():
        if line.strip() and not line.lstrip().startswith("#"):
            key, _, value = line.partition(":")
            meta[key.strip()] = value.strip().strip("\"'")
    for key in ("title", "repo", "sha"):
        if not meta.get(key):
            sys.exit(f"front matter: `{key}` is required")
    if not re.fullmatch(r"[0-9a-f]{40}", meta["sha"]):
        sys.exit("front matter: `sha` must be a full 40-character commit hash")
    return meta, text[match.end():]


class Links:
    def __init__(self, meta):
        self.repo, self.sha, self.pr = meta["repo"], meta["sha"], meta.get("pr", "")
        self.checkout = meta.get("checkout", "")
        self.count = 0
        if not self.checkout:
            warn("no `checkout` in the front matter: gh:, tree: and commit: links are not verified")
        elif self.git("cat-file", "-e", f"{self.sha}^{{commit}}").returncode:
            warn(f"commit {self.sha[:10]} not found in {self.checkout}")
            self.checkout = ""

    def git(self, *args):
        return subprocess.run(["git", "-C", self.checkout, *args], capture_output=True, text=True)

    def resolve(self, scheme, target, where):
        self.count += 1
        base = f"https://github.com/{self.repo}"
        if scheme == "pr":
            if not self.pr:
                warn(f"{where}: pr: link without `pr` in the front matter")
            return f"{base}/pull/{self.pr}"
        if scheme == "commit":
            return f"{base}/pull/{self.pr}/commits/{self.commit(target, where)}" if self.pr \
                else f"{base}/commit/{self.commit(target, where)}"
        path, _, anchor = target.partition("#")
        path = path.strip("/")
        if scheme == "tree":
            self.check_tree(path, where)
            return f"{base}/tree/{self.sha}/{path}".rstrip("/")
        self.check_blob(path, anchor, where)
        return f"{base}/blob/{self.sha}/{path}" + (f"#{anchor}" if anchor else "")

    def commit(self, target, where):
        if not self.checkout:
            return target
        result = self.git("rev-parse", "--verify", "--quiet", f"{target}^{{commit}}")
        if result.returncode:
            warn(f"{where}: unknown commit {target}")
            return target
        full = result.stdout.strip()
        if self.git("merge-base", "--is-ancestor", full, self.sha).returncode:
            warn(f"{where}: commit {target} is not in the history of {self.sha[:10]}")
        return full

    def check_tree(self, path, where):
        if self.checkout and path and self.git("cat-file", "-e", f"{self.sha}:{path}").returncode:
            warn(f"{where}: {path} does not exist at {self.sha[:10]}")

    def check_blob(self, path, anchor, where):
        if not self.checkout:
            return
        result = self.git("cat-file", "-p", f"{self.sha}:{path}")
        if result.returncode:
            warn(f"{where}: {path} does not exist at {self.sha[:10]}")
            return
        lines = [int(n) for n in re.findall(r"L(\d+)", anchor)]
        length = result.stdout.count("\n") + (0 if result.stdout.endswith("\n") else 1)
        if any(n > length for n in lines):
            warn(f"{where}: {path} has {length} lines, anchor #{anchor} is past the end")


def resolve_links(body, links):
    def replace(match):
        where = f"GUIDE.md:{body.count(chr(10), 0, match.start()) + OFFSET}"
        return match.group(1) + links.resolve(match.group(2), match.group(3), where)

    return SCHEME_LINK.sub(replace, body)


def check_sources(body):
    for number, line in enumerate(body.splitlines(), OFFSET):
        for ref in UNPINNED.findall(line):
            if not re.fullmatch(r"[0-9a-f]{40}", ref):
                warn(f"GUIDE.md:{number}: GitHub link pinned to `{ref}`, use gh:/tree: or a full commit hash")
    table = []
    for number, line in enumerate(body.splitlines() + [""], OFFSET):
        if line.lstrip().startswith("|"):
            table.append((number, len(re.findall(r"(?<!\\)\|", line))))
            continue
        if table and any(cells != table[0][1] for _, cells in table):
            for row, cells in table:
                if cells != table[0][1]:
                    warn(f"GUIDE.md:{row}: table row has {cells - 1} cells, header has {table[0][1] - 1} (a `|` inside a cell?)")
        table = []


def pandoc(markdown):
    result = subprocess.run(["pandoc", "-f", "commonmark_x", "-t", "html5", "--wrap=none"],
                            input=markdown, capture_output=True, text=True)
    if result.returncode:
        sys.exit(result.stderr)
    return result.stdout


def badge(status):
    kind = {"2": "good", "3": "info", "4": "warning", "5": "error"}[status[0]]
    return f'<span class="badge badge--{kind}">{status}</span>'


def http_block(match):
    lines = html.unescape(match.group(1)).split("\n")
    out = []
    for i, line in enumerate(lines):
        start = re.match(rf"(HTTP/[\d.]+) ({STATUS})(.*)$", line)
        request = re.match(r"(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS) (\S+)(.*)$", line)
        header = re.match(r"([A-Za-z-]+):(.*)$", line)
        if i == 0 and start:
            kind = "ok" if start.group(2)[0] in "23" else "ko"
            out.append(f'<span class="h-proto">{start.group(1)}</span> <span class="h-{kind}">{start.group(2)}{html.escape(start.group(3))}</span>')
        elif i == 0 and request:
            out.append(f'<span class="h-method">{request.group(1)}</span> <span class="h-path">{html.escape(request.group(2))}</span>{html.escape(request.group(3))}')
        elif header:
            out.append(f'<span class="h-header">{header.group(1)}</span>:{html.escape(header.group(2))}')
        else:
            out.append(html.escape(line))
    return '<pre class="http"><code>' + "\n".join(out) + "</code></pre>"


def enhance(fragment):
    fragment = re.sub(r'<pre class="http"><code>(.*?)</code></pre>', http_block, fragment, flags=re.S)
    fragment = fragment.replace("<pre><code>", '<pre class="plain"><code>')
    fragment = re.sub(r"(<table>.*?</table>)", r'<div class="table-wrap">\1</div>', fragment, flags=re.S)
    fragment = re.sub(rf'<span class="status">({STATUS})</span>', lambda m: badge(m.group(1)), fragment)
    fragment = re.sub(rf"<td>({STATUS})</td>", lambda m: f"<td>{badge(m.group(1))}</td>", fragment)
    fragment = re.sub(r'(<div class="callout[^"]*">\s*)<p><strong>(.*?)</strong></p>',
                      r'\1<p class="callout-title">\2</p>', fragment, flags=re.S)
    return fragment


def slug(name):
    folded = name.lower()
    for accented, plain in {"é": "e", "è": "e", "ê": "e", "à": "a", "ç": "c", "ô": "o", "î": "i", "&": "et"}.items():
        folded = folded.replace(accented, plain)
    return re.sub(r"[^a-z0-9]+", "-", folded).strip("-")


def unique_ids(panels):
    seen = set()
    for key, _, content in panels:
        seen.add(key)
    result = []
    for key, name, content in panels:
        def rename(match):
            ident = match.group(1)
            if ident in seen:
                ident = f"{key}-{ident}"
            seen.add(ident)
            return f'id="{ident}"'
        result.append((key, name, re.sub(r'id="([^"]+)"', rename, content)))
    return result


def check_output(page):
    text = re.sub(r"<(pre|code)[^>]*>.*?</\1>", "", page, flags=re.S)
    for leftover in sorted(set(re.findall(r"\[[^\]<>]+\]\[[^\]<>]*\]", text))):
        warn(f"unresolved reference link {leftover}")
    for src in re.findall(r'<img [^>]*src="([^"]+)"', page):
        if not re.match(r"[a-z]+:", src) and not (ROOT / src).exists():
            warn(f"missing image {src}")
    for img in re.findall(r"<img [^>]*>", page):
        if 'alt=""' in img:
            warn(f"image without alt text: {img[:80]}")


def check_urls(page):
    for url in sorted(set(re.findall(r'(?:href|src)="(https?://[^"#]+)', page))):
        try:
            request = urllib.request.Request(url, method="HEAD", headers={"User-Agent": "pr-review-guide"})
            status = urllib.request.urlopen(request, timeout=15).status
        except Exception as error:
            status = getattr(error, "code", error)
        if status != 200:
            warn(f"{url} answered {status}")


SCRIPT = """<script>
(function () {
  var tabs = [].slice.call(document.querySelectorAll('.tab'));
  var panels = [].slice.call(document.querySelectorAll('.panel'));
  if (!panels.length) return;
  document.documentElement.classList.add('js');
  function select(id, focus) {
    panels.forEach(function (p) { p.hidden = p.id !== id; });
    tabs.forEach(function (t) {
      var on = t.getAttribute('aria-controls') === id;
      t.setAttribute('aria-selected', on ? 'true' : 'false');
      t.tabIndex = on ? 0 : -1;
      if (on && focus) t.focus();
    });
  }
  function fromHash() {
    var target = location.hash && document.getElementById(decodeURIComponent(location.hash.slice(1)));
    var panel = target && target.closest('.panel');
    select(panel ? panel.id : panels[0].id);
    if (target && target !== panel) target.scrollIntoView();
  }
  tabs.forEach(function (tab, i) {
    tab.addEventListener('click', function () {
      select(tab.getAttribute('aria-controls'));
      history.replaceState(null, '', '#' + tab.getAttribute('aria-controls'));
    });
    tab.addEventListener('keydown', function (e) {
      var step = e.key === 'ArrowRight' ? 1 : e.key === 'ArrowLeft' ? -1 : 0;
      if (step) { var next = tabs[(i + step + tabs.length) % tabs.length]; next.click(); next.focus(); }
    });
  });
  window.addEventListener('hashchange', fromHash);
  fromHash();
})();
</script>"""


def main():
    global OFFSET
    raw = SOURCE.read_text(encoding="utf-8")
    meta, body = front_matter(raw)
    OFFSET = raw[: len(raw) - len(body)].count("\n") + 1
    labels = LABELS.get(meta.get("lang", "fr"), LABELS["fr"])

    check_sources(body)
    links = Links(meta)
    body = resolve_links(body, links)

    references = "\n".join(REF_DEFINITION.findall(body))
    body = REF_DEFINITION.sub("", body)
    parts = TAB_MARKER.split(body)
    parts = [re.sub(r"<!--.*?-->\n?", "", part, flags=re.S) if i % 2 == 0 else part for i, part in enumerate(parts)]
    intro, tabs = parts[0], list(zip(parts[1::2], parts[2::2]))

    def render(markdown):
        return enhance(pandoc(markdown + "\n\n" + references))

    intro_html = render(intro).replace("<p>", '<p class="lede">', 1)
    panels = unique_ids([(slug(name), name, render(content)) for name, content in tabs])
    tab_buttons = "\n".join(
        f'    <button type="button" class="tab" role="tab" id="tab-{key}" aria-controls="{key}" '
        f'aria-selected="{"true" if i == 0 else "false"}">{html.escape(name)}</button>'
        for i, (key, name, _) in enumerate(panels))
    panel_blocks = "\n".join(
        f'  <section class="panel" role="tabpanel" id="{key}" aria-labelledby="tab-{key}" tabindex="0">\n'
        f'    <h2 class="panel-title">{html.escape(name)}</h2>\n{content}  </section>'
        for key, name, content in panels)
    nav = f'  <div class="tabs" role="tablist" aria-label="{labels["tabs"]}">\n{tab_buttons}\n  </div>\n' if panels else ""
    kicker = f'  <p class="kicker">{html.escape(meta["kicker"])}</p>\n' if meta.get("kicker") else ""
    footer = meta.get("footer") or labels["footer"].format(sha=meta["sha"][:7])

    page = f"""<!DOCTYPE html>
<html lang="{meta.get("lang", "fr")}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>{html.escape(meta["title"])}</title>
<link rel="stylesheet" href="style.css">
</head>
<body>
<main class="container">
{kicker}  <h1>{html.escape(meta["title"])}</h1>
{intro_html}
{nav}{panel_blocks}
</main>
<footer><div class="container">{html.escape(footer)}</div></footer>
{SCRIPT}
</body>
</html>
"""
    check_output(page)
    if "--check-urls" in sys.argv:
        check_urls(page)
    OUTPUT.write_text(page, encoding="utf-8")
    for message in WARNINGS:
        print(f"warning: {message}", file=sys.stderr)
    print(f"{len(panels)} tabs, {links.count} pinned links, {len(WARNINGS)} warnings")


OFFSET = 1

if __name__ == "__main__":
    main()
