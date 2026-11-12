"""Inline SVG diagrams of the guide's Flows tab, injected by build.py where GUIDE.md holds
`<!-- diagram: name -->` on its own line.

Write one function per diagram taking the front matter (`meta`) and returning
`d.svg()`, and register it in DIAGRAMS. Coordinates are absolute: lay the boxes
out on a grid (lanes 20 px from the edges, boxes 30 px inside, 25 to 45 px
between rows). The build fails, rather than ship a wrong diagram, when:
  - a path linked with `d.url(path, line)` does not exist at the pinned commit
    in `checkout`, or the line is beyond the end of the file;
  - a non-title line is likely to overflow its box (CHAR px per character);
  - GUIDE.md names a diagram missing from DIAGRAMS.

Box lines are (text, cls, link): cls `t` title, `s` secondary, `c` code, `e`
error code. Box kinds (CSS in style.css): step, api, store, hub, move, copy,
note, wall, error. Edge kinds: "" (plain), error, api, move, copy.

Example, a two-step flow whose second box links a method:

    def approval(meta):
        d = Diagram(meta, 700, 220, "Approval flow", "ap")
        d.lane(20, 20, 660, 180, "Consumer space")
        a = d.box(50, 50, 600, [("Group waiting for validation", "t", None)])
        b = d.box(50, 120, 600, [
            ("Consumer::ApproveDocumentsGroup", "t", d.url("app/organizers/consumer/approve_documents_group.rb", 12)),
            ("approves every pending document", "s", None)], kind="store")
        down(d, a, b)
        return d.svg()

    DIAGRAMS = {"approval": approval}
"""

import html
import subprocess

CHAR = 6.9
LINE = 17


class Diagram:
    def __init__(self, meta, width, height, title, key):
        self.key = key
        self.meta = meta
        self.width = width
        self.height = height
        self.title = title
        self.parts = []
        self.errors = []

    def url(self, path, line=None):
        sha = self.meta["sha"]
        checkout = self.meta.get("checkout")
        if checkout:
            try:
                content = subprocess.run(["git", "-C", checkout, "show", f"{sha}:{path}"],
                                         capture_output=True, text=True, check=True).stdout
                if line and line > content.count("\n") + 1:
                    self.errors.append(f"{path}#L{line} beyond the end of the file")
            except subprocess.CalledProcessError:
                self.errors.append(f"{path} missing at {sha[:9]}")
        anchor = f"#L{line}" if line else ""
        return f"https://github.com/{self.meta['repo']}/blob/{sha}/{path}{anchor}"

    def text(self, x, y, value, cls="t", anchor="start", href=None):
        node = f'<text x="{x}" y="{y}" class="{cls}" text-anchor="{anchor}">{html.escape(value)}</text>'
        if href:
            node = f'<a href="{html.escape(href)}" target="_blank" rel="noopener">{node}</a>'
        self.parts.append(node)

    def box(self, x, y, w, lines, kind="step", href=None):
        """lines: list of (text, cls, link) where cls is t (title), s (secondary), c (code), e (error)."""
        h = 14 + LINE * len(lines)
        self.parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="6" class="box {kind}"/>')
        for i, (value, cls, link) in enumerate(lines):
            self.text(x + 10, y + 21 + i * LINE, value, cls, href=link)
            if len(value) * CHAR > w - 16 and cls != "t":
                self.errors.append(f"text may overflow its box: {value}")
        return (x, y, w, h)

    def lane(self, x, y, w, h, label):
        self.parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="10" class="lane"/>')
        self.text(x + 12, y + 20, label, "lane-label")

    def arrow(self, points, label=None, kind="", label_at=None):
        d = " ".join(f"{'M' if i == 0 else 'L'}{px} {py}" for i, (px, py) in enumerate(points))
        self.parts.append(f'<path d="{d}" class="edge {kind}" marker-end="url(#{self.key}-arrow{"-" + kind if kind else ""})"/>')
        if label:
            lx, ly = label_at or points[len(points) // 2]
            self.text(lx, ly, label, f"edge-label {kind}")

    def svg(self):
        if self.errors:
            raise SystemExit("diagram errors:\n  " + "\n  ".join(self.errors))
        defs = "".join(
            f'<marker id="{self.key}-arrow{suffix}" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">'
            f'<path d="M0 0 L10 5 L0 10 z" class="head{suffix}"/></marker>'
            for suffix in ("", "-error", "-api", "-move", "-copy"))
        body = "".join(self.parts)
        return (f'<div class="diagram"><svg role="img" aria-label="{html.escape(self.title)}" width="{self.width}" '
                f'height="{self.height}" viewBox="0 0 {self.width} {self.height}" xmlns="http://www.w3.org/2000/svg">'
                f'<defs>{defs}</defs>{body}</svg></div>')


def bottom(b):
    x, y, w, h = b
    return (x + w // 2, y + h)


def top(b):
    x, y, w, h = b
    return (x + w // 2, y)


def down(d, a, b, label=None, kind=""):
    (ax, ay), (bx, by) = bottom(a), top(b)
    d.arrow([(ax, ay), (bx, by)], label, kind, (ax + 8, (ay + by) // 2 + 4) if label else None)


DIAGRAMS = {}


def render(name, meta):
    if name not in DIAGRAMS:
        raise SystemExit(f"diagram '{name}' is not defined in diagrams.py")
    return DIAGRAMS[name](meta)
