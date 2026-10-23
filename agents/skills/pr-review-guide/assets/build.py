#!/usr/bin/env python3
"""Builds index.html from GUIDE.md. Edit GUIDE.md, then run `python3 build.py`.

index.html is overwritten on each run: never edit it by hand. Requires pandoc
(3.x, for commonmark_x). `--check-urls` also fetches every external link; links into
a private repository are checked with `gh` (the pinned commit is pushed), since
they answer 404 to an anonymous request.

GUIDE.md syntax, on top of CommonMark:
  front matter       title, repo (owner/name), sha (40 hex), plus optional kicker,
                     lang, pr, checkout (local clone used to verify links), footer
  <!-- tab: Name --> starts a tab; what comes before the first one is the intro
  <!-- subtab: Name --> inside a tab, starts a sub-tab (DSFR segmented control);
                     what comes before the first one stays above the switch
  gh:path#L10-L20    file at the pinned sha, verified against the local clone
  tree:path          directory at the pinned sha
  commit:abc1234     commit page, inside the PR when `pr` is set
  pr:                the pull request
  ::: callout        callout box; with a variant, ::: {.callout .warning}
                     (.info, .good or .warning: `::: callout .warning` is
                     not a div and renders as text); a first
                     paragraph made only of bold text becomes its title
  [503]{.status}     HTTP status badge; cells of a table column headed
                     "Statut", "Status" or "HTTP" get one too
  ::: {.chart .bars target=1}
                     bar chart from the table inside: first column labels,
                     one bar track per other column (e.g. base branch, PR);
                     a row with empty value cells is a group heading; with
                     `target`, a dashed line marks it and bars are colored
                     on target, above or below; optional `max`
  ::: {.chart .stack}
                     one stacked bar from a two-column table (label, value),
                     shares and total computed
                     both: a first paragraph made only of bold text is the
                     title, other paragraphs are the caption
  ::: flows          side-by-side flows, each a ::: {.flow title="…"} holding
                     a list: one node per item, arrows between them; an item
                     starting with "↓" is an arrow label, [text]{.ok},
                     {.dup} or {.none} colors a node, a nested list splits
                     into nodes side by side

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
    "fr": {"tabs": "Sections du guide", "footer": "Guide de revue — liens figés sur le commit {sha}.",
           "on_target": "sur la cible", "above": "au-dessus", "below": "en dessous", "total": "total"},
    "en": {"tabs": "Guide sections", "footer": "Review guide — links pinned to commit {sha}.",
           "on_target": "on target", "above": "above", "below": "below", "total": "total"},
}

STATUS = r"[1-5]\d\d"
STATUS_HEADERS = {"statut", "status", "http", "code http"}
TAB_MARKER = re.compile(r"^<!-- (?:sub)?tab: (.+?) -->\s*$")
SUBTAB_SPLIT = re.compile(r"^<!-- subtab: (.+?) -->\s*$", re.M)
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


def div(classes, blocks, style=None):
    return {"t": "Div", "c": [["", classes, [["style", style]] if style else []], blocks]}


def plain(inlines):
    return {"t": "Plain", "c": inlines}


def text(inlines):
    return {"t": "Str", "c": inlines}


def stringify(node):
    if isinstance(node, list):
        return "".join(stringify(item) for item in node)
    if not isinstance(node, dict):
        return ""
    kind = node.get("t")
    if kind == "Str":
        return node["c"]
    if kind in ("Space", "SoftBreak", "LineBreak"):
        return " "
    if kind == "Code":
        return node["c"][1]
    return stringify(node.get("c", []))


def cell_inlines(cell):
    blocks = cell[4]
    return blocks[0]["c"] if blocks and blocks[0]["t"] in ("Plain", "Para") else []


def table_rows(table):
    _, _, _, head, bodies, _ = table["c"]
    rows = list(head[1])
    for body in bodies:
        rows += body[2] + body[3]
    return [[cell_inlines(cell) for cell in row[1]] for row in rows]


def number(inlines, where):
    raw = re.sub(r"[\s  _]", "", stringify(inlines))
    if not raw:
        return None
    try:
        return float(raw.replace(",", "."))
    except ValueError:
        warn(f"{where}: `{stringify(inlines)}` is not a number")
        return None


def grouped(value, lang):
    rendered = f"{value:,.0f}" if value == int(value) else f"{value:,.1f}"
    return rendered.replace(",", " ") if lang == "fr" else rendered


def chart_parts(blocks):
    title, caption, table = None, [], None
    for block in blocks:
        if block["t"] == "Table" and table is None:
            table = block
        elif title is None and not caption and block["t"] == "Para" and len(block["c"]) == 1 and block["c"][0]["t"] == "Strong":
            title = block["c"][0]["c"]
        else:
            caption.append(block)
    head = [div(["chart-title"], [plain(title)])] if title else []
    return head + [div(["chart-sub"], caption)] if caption else head, table


def bars_chart(attr, blocks, labels):
    options = dict(attr[2])
    head, table = chart_parts(blocks)
    if table is None:
        warn("::: {.chart .bars} without a table")
        return div(["chart"], head)
    header, *rows = table_rows(table)
    values = [[number(cell, "bar chart") for cell in row[1:]] for row in rows]
    target = float(options["target"]) if "target" in options else None
    top = float(options.get("max") or max([v for row in values for v in row if v is not None] + [target or 0, 1]))
    columns = len(header) - 1
    grid = [div(["head", "first"], [plain(header[0])])] + [div(["head"], [plain(cell)]) for cell in header[1:]]
    for row, numbers in zip(rows, values):
        if all(v is None for v in numbers):
            grid.append(div(["group"], [plain(row[0])]))
            continue
        grid.append(div(["label"], [plain(row[0])]))
        for column, value in enumerate(numbers):
            if value is None:
                grid.append(div(["track"], []))
                continue
            if target is None:
                tone = f"series-{column % 4 + 1}"
            else:
                tone = "ok" if value == target else "dup" if value > target else "none"
            width = f"width:{value / top * 100:.2f}%" if value else None
            bar = div(["bar", tone] + ([] if value else ["zero"]), [plain([text(grouped(value, labels["lang"]))])], width)
            grid.append(div(["track"], [bar]))
    style = f"grid-template-columns:minmax(10rem,1.3fr) repeat({columns},1fr);--columns:{columns}"
    if target is not None:
        style += f";--target:{target / top * 100:.2f}%"
        legend = [div(["chart-legend"], [plain([
            {"t": "Span", "c": [["", [tone], []], [text(labels[key])]]}
            for tone, key in (("ok", "on_target"), ("dup", "above"), ("none", "below"))])])]
    else:
        legend = []
    return div(["chart"], head + legend + [div(["paths"] + (["targeted"] if target is not None else []), grid, style)])


def stack_chart(attr, blocks, labels):
    head, table = chart_parts(blocks)
    if table is None:
        warn("::: {.chart .stack} without a table")
        return div(["chart"], head)
    _, *rows = table_rows(table)
    parts = [(row[0], number(row[1] if len(row) > 1 else [], "stacked bar")) for row in rows]
    parts = [(label, value) for label, value in parts if value]
    total = sum(value for _, value in parts)
    lang = labels["lang"]
    segments = [div([f"series-{i % 4 + 1}"], [plain([text(grouped(value, lang))])], f"flex:{value}") for i, (label, value) in enumerate(parts)]
    legend = []
    for i, (label, value) in enumerate(parts):
        share = value / total * 100
        legend.append({"t": "Span", "c": [["", [f"series-{i % 4 + 1}"], []],
                       label + [text(f" {grouped(value, lang)} ({share:.0f} %)" if lang == "fr" else f" {grouped(value, lang)} ({share:.0f}%)")]]})
    legend.append({"t": "Span", "c": [["", ["total"], []], [text(f"{labels['total']} {grouped(total, lang)}")]]})
    return div(["chart"], head + [div(["stack"], segments), div(["chart-legend"], [plain(legend)])])


def flow_node(inlines):
    if len(inlines) == 1 and inlines[0]["t"] == "Span":
        classes = [c for c in inlines[0]["c"][0][1] if c in ("ok", "dup", "none", "entry")]
        if classes:
            return div(["node"] + classes, [plain(inlines[0]["c"][1])])
    return div(["node"], [plain(inlines)])


def flow_lane(items):
    if any(item and item[0]["t"] == "Para" for item in items):
        warn("::: flow: a list with blank lines between items is one lane; start each lane with another marker (- then *)")
    out = []
    for position, item in enumerate(items):
        inlines = item[0]["c"] if item and item[0]["t"] in ("Plain", "Para") else []
        if stringify(inlines).startswith("↓"):
            out.append(div(["arrow"], [plain(inlines)]))
            continue
        if out and "arrow" not in out[-1]["c"][0][1]:
            out.append(div(["arrow"], [plain([text("↓")])]))
        node = flow_node(inlines)
        if position == 0 and len(node["c"][0][1]) == 1:
            node["c"][0][1].append("entry")
        out.append(node)
        nested = [b for b in item[1:] if b["t"] in ("BulletList", "OrderedList")]
        for listing in nested:
            entries = listing["c"] if listing["t"] == "BulletList" else listing["c"][1]
            out.append(div(["arrow"], [plain([text("↓")])]))
            out.append(div(["split"], [flow_node(e[0]["c"] if e and e[0]["t"] in ("Plain", "Para") else []) for e in entries]))
    return div(["lane"], out)


def flow(attr, blocks):
    title = dict(attr[2]).get("title")
    out = [div(["flow-title"], [plain([text(title)])])] if title else []
    for block in blocks:
        if block["t"] == "BulletList":
            out.append(flow_lane(block["c"]))
        elif block["t"] == "OrderedList":
            out.append(flow_lane(block["c"][1]))
        else:
            out.append(block)
    return div(["flow"], out)


def transform(ast, links, labels):
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
        if kind == "Div" and {"chart", "bars"} <= set(node["c"][0][1]):
            return bars_chart(node["c"][0], walk(node["c"][1], visit), labels)
        if kind == "Div" and {"chart", "stack"} <= set(node["c"][0][1]):
            return stack_chart(node["c"][0], walk(node["c"][1], visit), labels)
        if kind == "Div" and "flow" in node["c"][0][1]:
            return flow(node["c"][0], walk(node["c"][1], visit))
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
    for leftover in sorted(set(re.findall(r"^<p>(:::.*?)(?:<|$)", text, flags=re.M))):
        warn(f"fenced div rendered as text: {leftover} (variants go in braces: ::: {{.callout .warning}})")
    for leftover in sorted(set(re.findall(r"\[[^\]<>]+\]\[[^\]<>]*\]", text))):
        warn(f"unresolved reference link {leftover}")
    for src in re.findall(r'<img [^>]*src="([^"]+)"', page):
        if not re.match(r"[a-z]+:", src) and not (ROOT / urllib.parse.unquote(src)).exists():
            warn(f"missing image {src}")
    for img in re.findall(r"<img [^>]*>", page):
        if 'alt=""' in img:
            warn(f"image without alt text: {img[:80]}")


def private_repo_urls(urls, repo, sha):
    """Links into a private repository answer 404 anonymously: check the commit is pushed with gh instead."""
    own = {url for url in urls if url.startswith(f"https://github.com/{repo}/")}
    if not own:
        return set()
    try:
        visibility = subprocess.run(["gh", "repo", "view", repo, "--json", "visibility", "-q", ".visibility"],
                                    capture_output=True, text=True, timeout=30).stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return set()
    if visibility not in ("PRIVATE", "INTERNAL"):
        return set()
    pushed = subprocess.run(["gh", "api", f"repos/{repo}/commits/{sha}", "--silent"], capture_output=True, timeout=30)
    if pushed.returncode:
        warn(f"commit {sha[:10]} is not on GitHub: push the branch before publishing")
    return own


def check_urls(page, repo, sha):
    urls = {html.unescape(u).split("#")[0] for u in re.findall(r'(?:href|src)="(https?://[^"]+)"', page)}
    for url in sorted(urls - private_repo_urls(urls, repo, sha)):
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
  var lists = [].slice.call(document.querySelectorAll('[role="tablist"]'));
  if (!lists.length) return;
  document.documentElement.classList.add('js');
  function tabsOf(list) {
    return [].slice.call(list.children).filter(function (t) { return t.getAttribute('role') === 'tab'; });
  }
  function select(tab) {
    tabsOf(tab.parentNode).forEach(function (t) {
      var on = t === tab;
      t.setAttribute('aria-selected', on ? 'true' : 'false');
      t.tabIndex = on ? 0 : -1;
      document.getElementById(t.getAttribute('aria-controls')).hidden = !on;
    });
  }
  function reveal(el) {
    for (var node = el; node && node.getAttribute; node = node.parentNode) {
      if (node.getAttribute('role') === 'tabpanel') select(document.getElementById('tab-' + node.id));
    }
  }
  lists.forEach(function (list) {
    var tabs = tabsOf(list);
    select(tabs[0]);
    tabs.forEach(function (tab, i) {
      tab.addEventListener('click', function () {
        select(tab);
        history.replaceState(null, '', '#' + tab.getAttribute('aria-controls'));
      });
      tab.addEventListener('keydown', function (e) {
        var step = e.key === 'ArrowRight' ? 1 : e.key === 'ArrowLeft' ? -1 : 0;
        if (step) { var next = tabs[(i + step + tabs.length) % tabs.length]; next.click(); next.focus(); }
      });
    });
  });
  function fromHash() {
    var target = location.hash && document.getElementById(decodeURIComponent(location.hash.slice(1)));
    if (!target) return;
    reveal(target);
    if (target.getAttribute('role') !== 'tabpanel') target.scrollIntoView();
  }
  window.addEventListener('hashchange', fromHash);
  fromHash();
})();
</script>"""


def with_subtabs(content, taken):
    parts = SUBTAB_SPLIT.split(content)
    if len(parts) == 1:
        return content
    head, subs = parts[0], [(slug(name, taken), name, body) for name, body in zip(parts[1::2], parts[2::2])]
    buttons = "\n".join(
        f'      <button type="button" class="subtab" role="tab" id="tab-{key}" aria-controls="{key}" '
        f'aria-selected="{"true" if i == 0 else "false"}">{html.escape(name)}</button>'
        for i, (key, name, _) in enumerate(subs))
    blocks = "\n".join(
        f'    <section class="subpanel" role="tabpanel" id="{key}" aria-labelledby="tab-{key}" tabindex="0">\n'
        f'      <h3 class="panel-title">{html.escape(name)}</h3>\n{body}    </section>'
        for key, name, body in subs)
    return f'{head}    <div class="subtabs" role="tablist">\n{buttons}\n    </div>\n{blocks}\n'


def main():
    raw = SOURCE.read_text(encoding="utf-8")
    meta, body = front_matter(raw)
    offset = raw[: len(raw) - len(body)].count("\n") + 1
    labels = {**LABELS.get(meta.get("lang", "fr"), LABELS["fr"]), "lang": meta.get("lang", "fr")}

    check_sources(body, offset)
    links = Links(meta, Source(body, offset))
    ast = json.loads(pandoc(["-f", "commonmark_x", "-t", "json"], body))
    ast["blocks"] = transform(ast["blocks"], links, labels)
    rendered = enhance(pandoc(["-f", "json", "-t", "html5", "--wrap=none"], json.dumps(ast)))

    parts = re.split(r"^<!-- tab: (.+?) -->\s*$", rendered, flags=re.M)
    intro, tabs = parts[0], list(zip(parts[1::2], parts[2::2]))
    intro = intro.replace("<p>", '<p class="lede">', 1)

    taken = set(re.findall(r'\sid="([^"]+)"', rendered))
    panels = [(slug(name, taken), name, with_subtabs(content, taken)) for name, content in tabs]
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
        check_urls(page, meta["repo"], meta["sha"])
    OUTPUT.write_text(page, encoding="utf-8")
    for message in WARNINGS:
        print(f"warning: {message}", file=sys.stderr)
    print(f"{len(panels)} tabs, {links.count} pinned links, {len(WARNINGS)} warnings")


if __name__ == "__main__":
    main()
