#!/usr/bin/env python3
import posixpath
import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit

REFERENCE_PATTERN = re.compile(r"""\b(?:href|src)\s*=\s*["']([^"']*)["']""", re.IGNORECASE)
HTML_SUFFIXES = {".html", ".htm"}


def resolve_reference(folder, page, reference):
    parts = urlsplit(reference)
    if parts.scheme or parts.netloc or not parts.path:
        return None

    path = unquote(parts.path)
    if path.startswith("/"):
        if not path.startswith(f"/{folder}/"):
            return None
        target = path
    else:
        target = posixpath.join("/", folder, posixpath.dirname(page), path)
    if target.endswith("/"):
        target += "index.html"
    return posixpath.normpath(target).lstrip("/")


def main():
    folder, stage = sys.argv[1], Path(sys.argv[2])
    local_files = [path.relative_to(stage).as_posix() for path in stage.rglob("*") if path.is_file()]
    remote_files = [line for line in sys.stdin.read().splitlines() if line]
    known_targets = {posixpath.join(folder, path) for path in local_files + remote_files}

    for page in sorted(path for path in local_files if Path(path).suffix.lower() in HTML_SUFFIXES):
        content = (stage / page).read_text(errors="replace")
        for reference in sorted(set(REFERENCE_PATTERN.findall(content))):
            target = resolve_reference(folder, page, reference)
            if target is not None and not {target, f"{target}/index.html"} & known_targets:
                print(f"{page} -> {reference}")


main()
