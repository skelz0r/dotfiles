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
                     paragraph made only of bold text becomes its title
  [503]{.status}     HTTP status badge; cells of a table column headed
                     "Statut", "Status" or "HTTP" get one too

Links are resolved on pandoc's syntax tree, so code blocks and inline code
are never touched, and the document is rendered in one pass, so every id is
unique across tabs.
"""

import html
import json
import pathlib
import re
import subprocess
import sys
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).parent
SOURCE = ROOT / "GUIDE.md"
OUTPUT = ROOT / "index.html"

LABELS = {
    "fr": {"tabs": "Sections du guide", "footer": "Guide de revue — liens figés sur le commit {sha}."},
    "en": {"tabs": "Guide sections", "footer": "Review guide — links pinned to commit {sha}."},
}

STATUS = r"[1-5]\d\d"
STATUS_HEADERS = {"statut", "status", "http", "code http"}
TAB_MARKER = re.compile(r"^<!-- tab: (.+?) -->\s*$")
GITHUB_URL = re.compile(r"^https?://github\.com/([^/]+/[^/]+)/(blob|tree)/([^/]+)/?(.*)$")
ANCHOR = re.compile(r"^L(\d+)(?:C\d+)?(?:-L(\d+)(?:C\d+)?)?$")
WARNINGS = []


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


class Source:
    """Locates a link target in GUIDE.md to give warnings a line number."""

    def __init__(self, text, offset):
        self.lines = text.splitlines()
        self.offset = offset

    def where(self, target):
        for number, line in enumerate(self.lines, self.offset):
            if target in line:
                return f"GUIDE.md:{number}"
        return "GUIDE.md"


class Links:
    def __init__(self, meta, source):
        self.repo, self.sha, self.pr = meta["repo"], meta["sha"], meta.get("pr", "")
        self.checkout = meta.get("checkout", "")
        self.source = source
        self.count = 0
        if not self.checkout:
            warn("no `checkout` in the front matter: gh:, tree: and commit: links are not verified")
        elif self.git("cat-file", "-e", f"{self.sha}^{{commit}}").returncode:
            warn(f"commit {self.sha[:10]} not found in {self.checkout}")
            self.checkout = ""

    def git(self, *args):
        return subprocess.run(["git", "-C", self.checkout, *args], capture_output=True, text=True)

    def url(self, kind, path, anchor=""):
        quoted = urllib.parse.quote(path, safe="/")
        return f"https://github.com/{self.repo}/{kind}/{self.sha}/{quoted}".rstrip("/") + (f"#{anchor}" if anchor else "")

    def resolve(self, target):
        scheme, _, rest = target.partition(":")
        if scheme not in ("gh", "tree", "commit", "pr"):
            self.check_external(target)
            return target
        self.count += 1
        where = self.source.where(target)
        base = f"https://github.com/{self.repo}"
        if scheme == "pr":
            if not self.pr:
                warn(f"{where}: pr: link without `pr` in the front matter")
            return f"{base}/pull/{self.pr}"
        if scheme == "commit":
            full = self.commit(rest, where)
            return f"{base}/pull/{self.pr}/commits/{full}" if self.pr else f"{base}/commit/{full}"
        path, _, anchor = rest.partition("#")
        path = urllib.parse.unquote(path).strip("/")
        if scheme == "tree":
            if anchor:
                warn(f"{where}: tree:{rest}: a directory link cannot carry an anchor")
            self.check_object(path, "tree", "", where)
            return self.url("tree", path)
        self.check_object(path, "blob", anchor, where)
        return self.url("blob", path, anchor)

    def check_external(self, target):
        match = GITHUB_URL.match(target)
        if not match:
            return
        repo, kind, ref, rest = match.groups()
        where = self.source.where(target)
        if not re.fullmatch(r"[0-9a-f]{40}", ref):
            warn(f"{where}: GitHub link pinned to `{ref}`, use gh:/tree: or a full commit hash")
            return
        if repo == self.repo and ref == self.sha:
            path, _, anchor = rest.partition("#")
            self.check_object(urllib.parse.unquote(path).strip("/"), kind, anchor, where)

    def commit(self, target, where):
        if not self.checkout:
            return target
        result = self.git("rev-parse", "--verify", "--quiet", f"{target}^{{commit}}")
        if result.returncode:
            warn(f"{where}: unknown or ambiguous commit {target}")
            return target
        full = result.stdout.strip()
        if self.git("merge-base", "--is-ancestor", full, self.sha).returncode:
            warn(f"{where}: commit {target} is not in the history of {self.sha[:10]}")
        return full

    def check_object(self, path, kind, anchor, where):
        if not self.checkout:
            return
        spec = f"{self.sha}:{path}"
        actual = self.git("cat-file", "-t", spec).stdout.strip()
        if not actual:
            warn(f"{where}: {path or '/'} does not exist at {self.sha[:10]}")
            return
        if actual != kind:
            warn(f"{where}: {path} is a {actual} at {self.sha[:10]}, not a {kind}")
            return
        if kind != "blob" or not anchor:
            return
        match = ANCHOR.match(anchor)
        if not match:
            warn(f"{where}: #{anchor} is not a line anchor (#L10, #L10-L20)")
            return
        start, end = int(match.group(1)), int(match.group(2) or match.group(1))
        content = self.git("cat-file", "-p", spec).stdout
        length = content.count("\n") + (0 if content.endswith("\n") or not content else 1)
        if not 1 <= start <= end <= length:
            warn(f"{where}: {path} has {length} lines, #{anchor} is out of range")


def walk(node, visit):
    if isinstance(node, dict):
        replacement = visit(node)
        if replacement is not None:
            return replacement
        if "c" in node:
            node["c"] = walk(node["c"], visit)
        return node
    if isinstance(node, list):
        out = []
        for item in node:
            walked = walk(item, visit)
            if isinstance(walked, list) and isinstance(item, dict):
                out.extend(walked)
            else:
                out.append(walked)
        return out
    return node


def transform(ast, links):
    def visit(node):
        kind = node.get("t")
        if kind in ("Link", "Image"):
            attr, inlines, (url, title) = node["c"]
            node["c"] = [attr, walk(inlines, visit), [links.resolve(url), title]]
            return node
        if kind in ("RawBlock", "RawInline"):
            fmt, text = node["c"]
            if fmt == "html" and text.lstrip().startswith("<!--") and not TAB_MARKER.match(text.strip()):
                return []
        if kind == "Div" and "callout" in node["c"][0][1]:
            blocks = node["c"][1]
            if blocks and blocks[0]["t"] == "Para" and len(blocks[0]["c"]) == 1 and blocks[0]["c"][0]["t"] == "Strong":
                blocks[0] = {"t": "Div", "c": [["", ["callout-title"], []], [{"t": "Plain", "c": blocks[0]["c"][0]["c"]}]]}
        return None

    return walk(ast, visit)


def pandoc(args, data):
    result = subprocess.run(["pandoc", *args], input=data, capture_output=True, text=True)
    if result.returncode:
        sys.exit(result.stderr)
    return result.stdout


def badge(status):
    kind = {"1": "info", "2": "good", "3": "info", "4": "warning", "5": "error"}[status[0]]
    return f'<span class="badge badge--{kind}">{status}</span>'


def http_block(match):
    lines = html.unescape(match.group(1)).split("\n")
    out = []
    for i, line in enumerate(lines):
        start = re.match(rf"(HTTP/[\d.]+) ({STATUS})(.*)$", line)
        request = re.match(r"(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS) (\S+)(.*)$", line)
        header = re.match(r"([A-Za-z-]+):(.*)$", line)
        if i == 0 and start:
            state = "ok" if start.group(2)[0] in "123" else "ko"
            out.append(f'<span class="h-proto">{start.group(1)}</span> <span class="h-{state}">{start.group(2)}{html.escape(start.group(3))}</span>')
        elif i == 0 and request:
            out.append(f'<span class="h-method">{request.group(1)}</span> <span class="h-path">{html.escape(request.group(2))}</span>{html.escape(request.group(3))}')
        elif header:
            out.append(f'<span class="h-header">{header.group(1)}</span>:{html.escape(header.group(2))}')
        else:
            out.append(html.escape(line))
    return '<pre class="http"><code>' + "\n".join(out) + "</code></pre>"


def status_columns(table):
    head = re.search(r"<thead>(.*?)</thead>", table, re.S)
    headers = re.findall(r"<th[^>]*>(.*?)</th>", head.group(1), re.S) if head else []
    columns = {i for i, cell in enumerate(headers) if re.sub("<[^>]+>", "", cell).strip().lower() in STATUS_HEADERS}
    if not columns:
        return table

    def row(match):
        cells = re.split(r"(<td[^>]*>.*?</td>)", match.group(0), flags=re.S)
        index = -1
        for position, part in enumerate(cells):
            if part.startswith("<td"):
                index += 1
                inner = re.match(r"(<td[^>]*>)(.*?)(</td>)", part, re.S)
                if index in columns and re.fullmatch(STATUS, inner.group(2).strip()):
                    cells[position] = inner.group(1) + badge(inner.group(2).strip()) + inner.group(3)
        return "".join(cells)

    return re.sub(r"<tr>.*?</tr>", row, table, flags=re.S)


def enhance(fragment):
    fragment = re.sub(r'<pre class="http"><code>(.*?)</code></pre>', http_block, fragment, flags=re.S)
    fragment = fragment.replace("<pre><code>", '<pre class="plain"><code>')
    fragment = re.sub(rf'<span class="status">({STATUS})</span>', lambda m: badge(m.group(1)), fragment)
    fragment = re.sub(r"<table>.*?</table>", lambda m: f'<div class="table-wrap">{status_columns(m.group(0))}</div>', fragment, flags=re.S)
    return fragment


def slug(name, taken):
    folded = name.lower()
    for accented, plain in {"é": "e", "è": "e", "ê": "e", "à": "a", "â": "a", "ç": "c", "ô": "o", "î": "i", "ù": "u", "&": "et"}.items():
        folded = folded.replace(accented, plain)
    base = re.sub(r"[^a-z0-9]+", "-", folded).strip("-") or "section"
    candidate, n = base, 1
    while candidate in taken or f"tab-{candidate}" in taken:
        n += 1
        candidate = f"{base}-{n}"
    taken.update({candidate, f"tab-{candidate}"})
    return candidate


def check_sources(body, offset):
    fence = None
    table = []
    for number, line in enumerate(body.splitlines() + [""], offset):
        marker = re.match(r"^\s*(`{3,}|~{3,})", line)
        if marker and (fence is None or marker.group(1)[0] == fence[0] and len(marker.group(1)) >= len(fence)):
            fence = None if fence else marker.group(1)
            continue
        if fence is None and line.lstrip().startswith("|"):
            table.append((number, len(re.findall(r"(?<!\\)\|", line))))
            continue
        if table and any(cells != table[0][1] for _, cells in table):
            for row, cells in table:
                if cells != table[0][1]:
                    warn(f"GUIDE.md:{row}: table row has {cells - 1} cells, header has {table[0][1] - 1} (a `|` inside a cell?)")
        table = []


def check_output(page):
    ids = re.findall(r'\sid="([^"]+)"', page)
    for duplicate in sorted({i for i in ids if ids.count(i) > 1}):
        warn(f"duplicate id #{duplicate}")
    known = set(ids)
    for target in sorted(set(re.findall(r'href="#([^"]+)"', page))):
        if urllib.parse.unquote(target) not in known:
            warn(f"link to #{target}, which no element carries")
    for leftover in sorted(set(re.findall(r'(?:href|src)="((?:gh|tree|commit|pr):[^"]*)"', page))):
        warn(f"unresolved link {leftover}")
    text = re.sub(r"<(pre|code)[^>]*>.*?</\1>", "", page, flags=re.S)
    for leftover in sorted(set(re.findall(r"\[[^\]<>]+\]\[[^\]<>]*\]", text))):
        warn(f"unresolved reference link {leftover}")
    for src in re.findall(r'<img [^>]*src="([^"]+)"', page):
        if not re.match(r"[a-z]+:", src) and not (ROOT / urllib.parse.unquote(src)).exists():
            warn(f"missing image {src}")
    for img in re.findall(r"<img [^>]*>", page):
        if 'alt=""' in img:
            warn(f"image without alt text: {img[:80]}")


def check_urls(page):
    urls = {html.unescape(u).split("#")[0] for u in re.findall(r'(?:href|src)="(https?://[^"]+)"', page)}
    for url in sorted(urls):
        status = None
        for method in ("HEAD", "GET"):
            try:
                request = urllib.request.Request(url, method=method, headers={"User-Agent": "pr-review-guide"})
                status = urllib.request.urlopen(request, timeout=15).status
            except Exception as error:
                status = getattr(error, "code", error)
            if status == 200:
                break
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
    raw = SOURCE.read_text(encoding="utf-8")
    meta, body = front_matter(raw)
    offset = raw[: len(raw) - len(body)].count("\n") + 1
    labels = LABELS.get(meta.get("lang", "fr"), LABELS["fr"])

    check_sources(body, offset)
    links = Links(meta, Source(body, offset))
    ast = json.loads(pandoc(["-f", "commonmark_x", "-t", "json"], body))
    ast["blocks"] = transform(ast["blocks"], links)
    rendered = enhance(pandoc(["-f", "json", "-t", "html5", "--wrap=none"], json.dumps(ast)))

    parts = re.split(r"^<!-- tab: (.+?) -->\s*$", rendered, flags=re.M)
    intro, tabs = parts[0], list(zip(parts[1::2], parts[2::2]))
    intro = intro.replace("<p>", '<p class="lede">', 1)

    taken = set(re.findall(r'\sid="([^"]+)"', rendered))
    panels = [(slug(name, taken), name, content) for name, content in tabs]
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
<html lang="{html.escape(meta.get("lang", "fr"))}">
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
{intro}
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


if __name__ == "__main__":
    main()
