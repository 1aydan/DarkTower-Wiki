# Dark Tower — Wiki

A designer-facing wiki generated from the project. Two layers in one site:

| Layer | Source of truth | Tool |
|---|---|---|
| **Design docs** (front door) | `RawDocs/*.md` | [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/) |
| **Code Reference** (C++ API) | doc-comments in `../Source/DarkTower` | [Doxygen](https://www.doxygen.nl/) + [doxygen-awesome-css](https://github.com/jothepro/doxygen-awesome-css) |

Nothing here is hand-maintained. Edit the source (`RawDocs/` or the C++ comments), rebuild, both refresh.

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

`serve.ps1` re-runs Doxygen each launch; while it's running, edits to `docs/` hot-reload. Re-launch it to pick up changes in `RawDocs/` or new C++ comments.

## Adding / changing content

- **New design doc:** drop a `.md` into `RawDocs/`, then add one line under `nav:` in `mkdocs.yml`.
  The **Design** landing page (`docs/design/index.md`) builds its own card for the page —
  title from the `#` heading, blurb from the first paragraph. Give it an icon by adding a line
  to `$icons` in `sync-docs.ps1`; skip that and it gets a generic doc icon.
  Forget the `nav:` line and the page still builds, but it is reachable only via search.
- **Home page:** `docs/index.md` is hand-written. Its card grid duplicates the Design landing
  page, so add a card there too, or point people at the Design tab.
- **Code reference:** just write normal `/** ... @param ... @return */` comments in the headers — they flow through automatically on the next build.

## Toolchain status — Material for MkDocs EOL

Material for MkDocs has been maintenance-only since 9.7.0 and is **end-of-life on 2026-11-05**.
Nothing breaks on that date; the toolchain simply stops receiving fixes. The site is static
HTML on an internal host, so sitting on a frozen 9.7.x is a legitimate long-term answer.

Ignore the **MkDocs 2.0** noise. It is unreleased — `pip install "mkdocs>=2.0"` returns
*No matching distribution* — and `mkdocs-material==9.*` pins `mkdocs<2` regardless.
`build.ps1` and `serve.ps1` set `NO_MKDOCS_2_WARNING` to suppress the banner Material
prints about it. Unset that variable to see it again.

If we do want a maintained toolchain later, in rough order of effort:

| Option | What it replaces | Notes |
|---|---|---|
| Stay on `mkdocs-material==9.*` | — | Works, frozen. Current choice. |
| [MaterialX](https://github.com/jaywhj/mkdocs-materialx) | the theme | Community fork of material 9.7.1, aims to be drop-in. |
| [Zensical](https://zensical.org/) | both | Official successor from the Material team, reads `mkdocs.yml`. Very early. |
| ProperDocs | the framework only | Fork of MkDocs 1.6.1; does not address Material's EOL by itself. |

This wiki is a cheap migration either way: no `custom_dir`, no theme overrides, one plugin
(`search`), stock `pymdownx` extensions. Worth revisiting around 2026-10.

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
  sync-docs.ps1       RawDocs/ -> docs/design/ + Design landing page
  ensure-doxygen-header.ps1   generates header.html for the dark-mode toggle
  RawDocs/            design docs, source of truth (hand-authored)
  docs/
    index.md          landing page (hand-authored)
    design/           <- generated: RawDocs/ + a generated index.md
    api/              <- generated: Doxygen HTML
  header.html         <- generated: patched Doxygen header (dark-mode toggle)
  .venv/              <- generated: Python env
  doxygen-awesome-css/<- generated: theme
  site/               <- generated: final static site
```
