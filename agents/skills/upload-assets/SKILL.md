---
name: upload-assets
description: Upload local files or folders to the static site assets.delmai.re (served from /var/www/assets on the apps server), public or behind a password per folder, and return their URLs. Use when the user wants to upload, host, publish or share files, images, PDFs, slides or a static HTML page on assets.delmai.re, or to put a password on (or remove it from) a folder there. Triggers on "upload assets", "upload sur assets", "mettre en ligne sur assets", "héberger sur assets.delmai.re", "protège par mot de passe", "mets un mdp sur le dossier".
---

# Upload assets

Publish local files to `https://assets.delmai.re/<folder>/...`.

Folders are **public** unless protected by a password: no directory listing,
but URLs are guessable. A protected folder asks for Basic auth on everything
below it, subfolders included (nginx honours a `.htpasswd` dropped in the
folder, the nearest one wins, down to 3 folder levels).

Wraps `upload-assets` (dotfiles `bin/upload-assets`) with a staging step that
strips image metadata and detects overwrites. Scripts below live in this
skill's base directory. To build an HTML page to publish here, see the
`static-page` skill.

## Workflow

### 1. Gather inputs

Three inputs are required. Ask for whichever the user has not already given.

- **Folder**: destination under the assets root, used exactly as given, never
  renamed. Allowed: letters, digits, `.`, `_`, `-`, and `/` for subfolders
  (`prez-editeurs`, `clients/acme`). Never upload at the root.
- **What to copy**: one or more local files and/or directories, optionally
  narrowed to a subset (see Selection).
- **Access**: public, or behind a password (see Access). When republishing
  to an existing folder, its current access is kept unless the user asks
  otherwise: no need to ask again.

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

### Access

- `--protect`: put a password on the folder, user `guest` unless
  `--user NAME`. The password is the one the user gave, passed through the
  `ASSETS_PASSWORD` environment variable (never on the command line),
  otherwise a random one is generated. On a protected folder, it replaces
  the password.
- `--public`: remove the folder's password. Refused when the password
  comes from a parent folder.
- Neither: keep the current access. A folder inside a protected one
  inherits its password.

To change the access of a folder already online, run both scripts with
`--protect` or `--public` and no source: nothing is uploaded.

The folder must be at most 3 levels deep to be protected
(`clients/acme/2026`). The `.htpasswd` lands on the server before the
files, so they are never public in between.

### 2. Prepare

```bash
[ASSETS_PASSWORD=...] scripts/prepare.sh [--only PATTERN]... [--except PATTERN]... \
  [--protect [--user NAME] | --public] <folder> <source> [<source>...]
```

Copies the selected files into a temporary staging dir (originals untouched),
strips EXIF/XMP/IPTC from images (keeps ICC profile and orientation), refuses
if GPS data remains, then compares with the server. Prints the staging dir,
the access the folder will have, files to upload, files that will be overwritten, remote files left untouched,
hidden entries skipped, and **broken local links**: `href`/`src` in uploaded
HTML pointing to a file neither uploaded nor already on the server, typically
a file left out by the selection.

Exit code 2 means invalid input: fix it with the user and re-run. To change
the selection, `rm -rf <stage>` and re-run with new patterns.

### 3. Confirm

Upload is outward-facing: always get an explicit go first. Recap:

- destination URL
- access: public, protected (new or replaced password), or protected by an
  existing password
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

Sets or removes the password, uploads with `upload-assets`, checks every
URL answers HTTP 200 (and 401 without credentials when protected), deletes
the staging dir on success and keeps it on failure for a retry. Prints the
access, with the user and password when it set one.

### 5. Report

Give the URLs, and the user and password when the folder was just
protected (an existing password is never shown: it is not stored anywhere
readable). For a static site with an `index.html` at the folder root, lead
with `https://assets.delmai.re/<folder>/`: nginx serves the `index.html` there
(and redirects `/<folder>` to it). Other pages are linked by full path. Many
files: entry points plus a count.

## Limits

- A password is shared by everyone who gets it: to revoke it, re-run with
  `--protect` to replace it.
- Upload never deletes: remote files absent locally stay on the server.
  Remove them only when explicitly asked:
  `ssh deploy@apps 'rm /var/www/assets/<folder>/<file>'`.
- PDF and office documents keep their metadata (author, software...).
- The link check only reads `href`/`src` attributes in HTML: CSS `url()`,
  `srcset` and links built by JavaScript are not checked. Absolute links
  outside `/<folder>/` are ignored.
- Requires `exiftool`, `jq`, `python3` and `openssl` (`htpasswd` is used
  when present for bcrypt hashes), and SSH access to `deploy@apps`.
