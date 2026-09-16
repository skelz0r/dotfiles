---
name: upload-assets
description: Upload local files or folders to the public static site assets.delmai.re (served from /var/www/assets on the apps server) and return their URLs. Use when the user wants to upload, host, publish or share files, images, PDFs, slides or a static HTML page on assets.delmai.re. Triggers on "upload assets", "upload sur assets", "mettre en ligne sur assets", "héberger sur assets.delmai.re".
---

# Upload assets

Publish local files to `https://assets.delmai.re/<folder>/...`.

Everything uploaded is **public**: no auth, no directory listing, but URLs are
guessable.

Wraps `upload-assets` (dotfiles `bin/upload-assets`) with a staging step that
strips image metadata and detects overwrites. Scripts below live in this
skill's base directory.

## Workflow

### 1. Gather inputs

Two inputs are required. Ask for whichever the user has not already given.

- **Folder**: destination under the assets root, used exactly as given, never
  renamed. Allowed: letters, digits, `.`, `_`, `-`, and `/` for subfolders
  (`prez-editeurs`, `clients/acme`). Never upload at the root.
- **What to copy**: one or more local files and/or directories, optionally
  narrowed to a subset (see Selection).

Existing folders, useful to reuse one or avoid a clash:

```bash
ssh deploy@apps 'ls /var/www/assets'
```

### Selection

When the user wants only part of a directory ("only the html and pdf", "not
the markdown sources"), look at what it holds first to pick patterns:

```bash
find <dir> -name '.*' -prune -o -type f -print
```

Then translate the request into patterns passed to `prepare.sh`:

- `--only PATTERN` (repeatable): keep only matching files.
- `--except PATTERN` (repeatable): drop matching files, applied after
  `--only`.

Patterns match paths relative to each source directory, case-insensitively.
`*` also crosses `/`, so `*.pdf` matches `docs/annexes/a.pdf`. A directory
name matches everything below it (`docs` or `docs/`). Files passed explicitly
as sources are always uploaded. An `--only` pattern matching nothing is an
error (likely a typo). Always quote patterns.

Examples: `--only '*.html' --only '*.pdf'`, `--except '*.md' --except drafts`,
`--only docs --only index.html`.

Rules applied by the scripts, mention them only when relevant:

- A directory's **contents** go into the folder: `slides/` to folder `prez`
  gives `prez/index.html`, not `prez/slides/index.html`.
- Hidden entries inside directories (`.env`, `.git`, `.DS_Store`...) are
  skipped.
- File names are kept as-is (spaces, accents); URLs are percent-encoded.
- Symlinks are replaced by the files they point to.

### 2. Prepare

```bash
scripts/prepare.sh [--only PATTERN]... [--except PATTERN]... <folder> <source> [<source>...]
```

Copies the selected files into a temporary staging dir (originals untouched),
strips EXIF/XMP/IPTC from images (keeps ICC profile and orientation), refuses
if GPS data remains, then compares with the server. Prints the staging dir,
files to upload, files that will be overwritten, remote files left untouched,
hidden entries skipped, and **broken local links**: `href`/`src` in uploaded
HTML pointing to a file neither uploaded nor already on the server, typically
a file left out by the selection.

Exit code 2 means invalid input: fix it with the user and re-run. To change
the selection, `rm -rf <stage>` and re-run with new patterns.

### 3. Confirm

Upload is public and outward-facing: always get an explicit go first. Recap:

- destination URL
- files to upload (full list if short, count otherwise)
- **overwrites**, stated explicitly: existing URLs will serve new content
- hidden entries skipped, if any
- broken local links, if any, with a suggested pattern change to include
  the missing files

If the user declines, `rm -rf <stage>`.

### 4. Publish

```bash
scripts/publish.sh <folder> <stage>
```

Uploads with `upload-assets`, checks every URL answers HTTP 200, deletes the
staging dir on success and keeps it on failure for a retry.

### 5. Report

Give the URLs. For a static site with an `index.html` at the folder root, lead
with `https://assets.delmai.re/<folder>/`: nginx serves the `index.html` there
(and redirects `/<folder>` to it). Other pages are linked by full path. Many
files: entry points plus a count.

## Limits

- Upload never deletes: remote files absent locally stay on the server.
  Remove them only when explicitly asked:
  `ssh deploy@apps 'rm /var/www/assets/<folder>/<file>'`.
- PDF and office documents keep their metadata (author, software...).
- The link check only reads `href`/`src` attributes in HTML: CSS `url()`,
  `srcset` and links built by JavaScript are not checked. Absolute links
  outside `/<folder>/` are ignored.
- Requires `exiftool`, `jq` and `python3`, and SSH access
  to `deploy@apps`.
