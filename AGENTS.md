# Repository Guidelines

## Project Structure & Module Organization

This repository provides Nix environments for reverse engineering on `x86_64-linux`.

- `flake.nix` exports packages, application launchers, development shells, and checks; `flake.lock` pins nixpkgs.
- `nix/tools.nix` groups tools and Python dependencies by workflow.
- `nix/jeb.nix` packages JEB, runtime dependencies, desktop integration, and regression checks.
- `nix/ida-pro/` contains IDA packaging and its download URL/hash manifest.
- `tests/` holds native GTK and Java SWT smoke tests. Icons come from packaged upstream assets.
- `reverse-skill/` is a Git submodule with separate contributor instructions. Read its `AGENTS.md` before changing it.

## Build, Test, and Development Commands

Run commands from the repository root:

```bash
nix develop .#binary               # IDA and binary analysis tools
nix develop .#android              # JEB and Android tools
nix build .#ida-pro .#jeb           # Build standalone packages
nix run .#ida                      # Launch IDA GUI
nix run .#jeb                      # Launch JEB GUI
nix flake check --no-build         # Evaluate outputs without building checks
nix flake check -L                 # Build and run registered regression checks
nix fmt                           # Format Nix files with nixfmt
```

The default development shell includes every tool group and can require substantial downloads. Add new files to Git before evaluating this Git-backed flake.

## Coding Style & Naming Conventions

Use nixfmt formatting, two-space Nix indentation, and lowercase kebab-case package names. Keep package-specific logic under `nix/`; keep tool selection in `nix/tools.nix`. Follow existing four-space indentation in C and Java tests. Quote shell paths and preserve argument boundaries with `"$@"`.

## Testing Guidelines

Checks use Nix derivations, Xvfb, and small C/Java programs; there is no coverage-percentage requirement. Test observable behavior: icon decoding, MIME lookup, WebKit rendering, and desktop registration. Use descriptive `*Smoke.c` and `*Smoke.java` names. For focused validation:

```bash
nix build .#checks.x86_64-linux.jeb-browser --no-link -L
nix build .#checks.x86_64-linux.jeb-desktop --no-link -L
```

## Commit & Pull Request Guidelines

The repository has no commits yet, so no historical message convention exists. Use concise Conventional Commit subjects such as `fix: provide JEB desktop icons`. Describe the problem, affected packages, validation results, and linked issues. Include screenshots for visible desktop changes.

## Configuration & Assets

Pin downloaded binaries by URL and SHA-256; review lockfile changes explicitly. Keep personal licenses, credentials, archives, and generated analysis files out of Git. Preserve user-managed desktop entries. Document changes to writable application directories and runtime initialization in `README.md`.
