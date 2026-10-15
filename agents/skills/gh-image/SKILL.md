---
name: gh-image
description: Attach local images or videos to GitHub issues, pull requests and comments with the native `--attach` flag of gh, which uploads them to GitHub and rewrites their references into hosted user-attachments URLs. Use whenever a screenshot, screencast or before/after evidence has to appear on GitHub, when the user asks to "mettre une capture sur la PR", "ajoute le screenshot à l'issue", "attache l'image", or to reuse a user-attachments URL in GitHub markdown, or when images already on GitHub are too big ("les screenshots sont trop gros"). Sizes portrait captures so they stay readable side by side. Records every uploaded screenshot or screencast in a manifest so /cleanup trashes it once the pull request is merged.
license: MIT
---

# gh-image

`gh pr` and `gh issue` take `--attach`: gh uploads the files to GitHub and
inserts their hosted references into the body. No standalone upload, no
cookie, no extension: plain `gh` authentication.

Images live on GitHub and inherit the repository visibility: on a private
repo only people with access see them. To share a file outside GitHub, use
the `upload-assets` skill instead.

## Verify support

```bash
gh --version
gh auth status
```

`--attach` requires gh 2.99.0 or newer; upgrade with `brew upgrade gh` if
the flag is missing from the target command's `--help`. The account needs
write access to the repo. GitHub.com and Enterprise Cloud only.

## Pick the files

Screenshots live in `~/share/screenshots/`, screencasts in
`~/share/screencasts/`. Look at each image before uploading and keep only
those that explain the change. Rename them to something meaningful
(`portal-before.png`, `portal-after.png`) when the original name is a
timestamp: gh uses the filename as alt text when none is given.

Run inside the target repo, or pass `--repo OWNER/REPO`.

| Destination         | Command                                                          |
|---------------------|------------------------------------------------------------------|
| New PR              | `gh pr create --title "..." --body-file body.md --attach a.png`  |
| Existing PR body    | `gh pr edit 123 --attach './a.png#Portal after the fix'`         |
| PR comment          | `gh pr comment 123 --body-file body.md --attach a.png`           |
| New issue           | `gh issue create --title "..." --body-file body.md --attach a.png` |
| Existing issue body | `gh issue edit 123 --attach './a.png#Login error state'`         |
| Issue comment       | `gh issue comment 123 --body-file body.md --attach a.png`        |

Repeat `--attach` per file, up to 50 per command. On `edit`, omitting body
flags keeps the current body and appends the attachments; `--body` or
`--body-file` replaces it.

## Place images in the body

Write the body to a file in the scratchpad and reference the local paths
where the images belong, keeping the user's style for PR descriptions and
comments (prose, no headings nor tables):

```markdown
The portal now lists expired documents first.

![Portal before the fix](/abs/path/portal-before.png)
![Portal after the fix](/abs/path/portal-after.png)
```

Then attach the same files:

```bash
gh pr edit 123 --body-file body.md \
  --attach /abs/path/portal-before.png \
  --attach /abs/path/portal-after.png
```

For an existing body, fetch it first with
`gh pr view 123 --json body --jq .body > body.md` (`gh issue view` for
issues), then edit the file.

gh rewrites matching markdown destinations to the uploaded URLs and keeps
their alt text; unreferenced attachments are appended at the end. Use
absolute paths: relative ones resolve from the command's working directory,
including those written in the body file. For appended images, give alt
text after `#` and quote paths with spaces. Videos render as players and
take no alt text: let gh generate their reference.

## Size the images

GitHub draws a markdown image at its natural size, capped at the body
width (about 880 px): a phone capture (750 × 1334 at 2x) then fills more
than a screen and before/after can no longer be compared. Check the
dimensions before uploading (`sips -g pixelWidth -g pixelHeight a.png`):

- crop very tall images (a Figma frame, a full-page capture) to the part
  that matters, at most about a screen ratio, under a new name, before
  attaching them;
- after the upload, replace each `![alt](https://github.com/user-attachments/…)`
  of a portrait capture by `<img src="…" alt="alt" width="240">`, and put
  the images to compare on the same line, separated by a space, so they
  render side by side (Figma, before, after);
- keep the markdown form for landscape or desktop captures already
  readable at body width.

gh only rewrites markdown destinations, not an `<img src>` holding a local
path: always attach with `![alt](/abs/path)`, then fetch the saved body,
swap in the `<img>` tags and save it with `gh pr edit --body-file`,
without `--attach`, which would upload the files a second time.

## Verify and recover

Create and edit print the resource URL, not the image markdown. Read the
saved body to confirm no local path remains:

```bash
gh pr view 123 --json body --jq .body
gh pr view 123 --comments
```

When some uploads fail, the command can still create or update the resource
with the others, then exit non-zero. Read stderr and the resource, then
retry only the missing files with `edit` on that resource, never a second
`create`.

## Record the uploads

Once the upload is confirmed, record the files so `/cleanup` trashes them
when the pull request is merged:

```bash
gh-media-log record --repo OWNER/REPO --pr 123 /abs/path/portal-before.png /abs/path/portal-after.png
```

Use `--issue 123` for an issue or an issue comment, `--pr 123` for a pull
request or its comments; for a `create`, take the number from the URL
gh prints. Record the final path, after any rename, and only the files
that made it: never one whose upload failed and was not retried
successfully. The command only keeps files under `~/share/screenshots/`
and `~/share/screencasts/` and skips the others, so pass every attached
file. Issue uploads are recorded but no command trashes them yet:
`gh-media-log purge --repo OWNER/REPO --issue 123` does it by hand.

No direct upload to READMEs, gists or Discussions: reuse a hosted URL from
a PR, issue or comment of the same repo.

## Troubleshooting

| Symptom                         | Action                                                                  |
|---------------------------------|-------------------------------------------------------------------------|
| Unknown `--attach` flag         | Upgrade gh, check the command's `--help`                                |
| Authentication failure          | `gh auth status`, check `GH_TOKEN` / `GITHUB_TOKEN` overrides           |
| Write-access error, upload 404  | `gh api repos/OWNER/REPO --jq .permissions`                             |
| Local path left in the body     | Check path, working directory, stderr; code spans are never rewritten   |
| Rejected file                   | Non-empty supported image or video; stderr gives type and size limits   |
