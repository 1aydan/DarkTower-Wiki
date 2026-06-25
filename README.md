# Dark Tower — Wiki

A designer-facing wiki generated from the project. Two layers in one site:

| Layer | Source of truth | Tool |
|---|---|---|
| **Design docs** (front door) | `../Docs/*.md` | [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/) |
| **Code Reference** (C++ API) | doc-comments in `../Source/DarkTower` | [Doxygen](https://www.doxygen.nl/) + [doxygen-awesome-css](https://github.com/jothepro/doxygen-awesome-css) |

Nothing here is hand-maintained. Edit the source (`/Docs` or the C++ comments), rebuild, both refresh.

## First-time setup (once per machine)

```powershell
cd Wiki
./setup.ps1
```

Installs into `Wiki/.venv` (MkDocs Material), installs **Doxygen** via winget, and downloads the theme. If `doxygen` isn't found afterward, open a fresh terminal so PATH updates.

> No winget? Install Doxygen manually from <https://www.doxygen.nl/download.html>, then re-run `setup.ps1` (it'll skip Doxygen and just grab the rest).
> Want class/collaboration diagrams? Install [Graphviz](https://graphviz.org/download/) and set `HAVE_DOT = YES` in `Doxyfile`.

## Daily use

```powershell
./serve.ps1     # live preview at http://127.0.0.1:8000
./build.ps1     # static site -> Wiki/site/  (copy/host this folder)
```

`serve.ps1` re-runs Doxygen each launch; while it's running, edits to `/Docs` hot-reload. Re-launch it to pick up new C++ comments.

## Adding / changing content

- **New design doc:** drop a `.md` into `../Docs`, then add one line under `nav:` in `mkdocs.yml`.
- **Code reference:** just write normal `/** ... @param ... @return */` comments in the headers — they flow through automatically on the next build.

## Hosting (read-only, internal)

`build.ps1` produces a fully static `Wiki/site/`. Drop it on any internal web share / IIS / S3-style static host. No server runtime needed.

## Publishing to GitHub Pages

> ⚠️ A public repo exposes the design docs and C++ source comments to anyone with the link. Only do this if that content is OK to be public.

One-time (this folder is already a git repo with `main` committed):

```powershell
gh auth login                                              # browser flow, once
gh repo create DarkTower-Wiki --public --source=. --remote=origin --push
gh api --method POST repos/<user>/DarkTower-Wiki/pages -f "source[branch]=gh-pages" -f "source[path]=/"
```

Every update after that:

```powershell
./publish.ps1     # build.ps1 + ghp-import push to the gh-pages branch
```

Site lands at `https://<user>.github.io/DarkTower-Wiki/` (~1 min after each push). `site_url` in `mkdocs.yml` must match that URL. To take it down: make the repo private or delete it (`gh repo delete`).

## Keep generated output out of SVN

```powershell
svn propset svn:ignore ".venv`nsite`ndoxygen-awesome-css`nheader.html`ndoxygen-warnings.log" .
svn propset svn:ignore "api`ndesign" docs
```

(Commit `mkdocs.yml`, `Doxyfile`, `docs/index.md`, the `*.ps1` scripts, and `requirements.txt`; ignore everything generated — including `header.html`, which `ensure-doxygen-header.ps1` regenerates to match the installed Doxygen version.)

The code reference gets a **dark/light toggle**, **copy-to-clipboard** buttons on code blocks, and clickable paragraph anchors, via [doxygen-awesome-css](https://github.com/jothepro/doxygen-awesome-css).

## Layout

```
Wiki/
  mkdocs.yml          MkDocs Material config + nav
  Doxyfile            Doxygen config (UE-macro-aware)
  requirements.txt    Python deps
  setup.ps1           one-time install
  build.ps1           static build -> site/
  serve.ps1           live preview
  ensure-doxygen-header.ps1   generates header.html for the dark-mode toggle
  docs/
    index.md          landing page (hand-authored)
    design/           <- generated: copied from /Docs
    api/              <- generated: Doxygen HTML
  header.html         <- generated: patched Doxygen header (dark-mode toggle)
  .venv/              <- generated: Python env
  doxygen-awesome-css/<- generated: theme
  site/               <- generated: final static site
```
