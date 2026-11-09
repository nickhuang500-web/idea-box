# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] — 2026-11-09

First public release.

### Added

- A frosted `＋ 想法` pill that floats above every window, on every Space and
  over full-screen apps.
- Click the pill to open a compact text box (`Enter` saves, `Shift+Enter` adds a
  line, `Esc` or clicking away folds it back). After a save the box folds itself
  back to the pill a second later.
- Every idea is appended to a single `~/Desktop/Ideas.md` file, grouped under one
  heading per month (`## November 2026`) with a `- 09 21:16` prefix per entry.
- Native AppKit implementation: no Electron, no browser, no runtime
  dependencies. Roughly 470 lines of Swift, one binary of ~120 KB.
- `scripts/build.sh` and a `Makefile` for a reproducible one-command build.
- Optional launch-at-login via a per-user LaunchAgent (`scripts/autostart.sh`).
- Light and dark appearance support for both the pill and the editor.

[Unreleased]: https://github.com/nickhuang500-web/idea-box/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/nickhuang500-web/idea-box/releases/tag/v1.0.0
