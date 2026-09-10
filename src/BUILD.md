# Packaging

The goal: one file the user downloads, double-clicks, and gets an app.

```
IndustrialAI-Setup.exe   →   double-click   →   installed
```

Inside, three things ship together:

```
Industrial AI Workbench
  ├─ Tauri shell          window + process lifecycle   (~6 MB)
  ├─ workbench-backend    frozen FastAPI               (~120 MB)
  └─ llama-server         llama.cpp                    (~5 MB)
```

Models are not bundled — they download on first use, the same way LM Studio
works. Bundling one small model is an option later if first-launch-offline
matters.

## Prerequisites

```bash
# Rust (Tauri is a Rust binary)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
cargo install tauri-cli --version "^2"

# Node
brew install node          # or your platform's equivalent

# llama.cpp — the build copies this binary in
brew install llama.cpp
```

Windows also needs the MSVC build tools and WebView2 (present on Windows 11).
Linux needs `libwebkit2gtk-4.1-dev`, `libssl-dev` and `libayatana-appindicator3-dev`.

## Build

```bash
./build/build.sh
```

Four stages: freeze the backend with PyInstaller, copy the sidecars in with
the target-triple suffix Tauri requires, build the frontend, bundle.

Installers land in `src-tauri/target/release/bundle/`:

| Platform | Output |
|---|---|
| Windows | `nsis/Industrial AI Workbench_0.1.0_x64-setup.exe` |
| macOS | `dmg/Industrial AI Workbench_0.1.0_aarch64.dmg` |
| Linux | `appimage/industrial-ai-workbench_0.1.0_amd64.AppImage` |

Each is a single file. Cross-compiling is not supported — build on the
platform you are shipping to.

## Develop

Faster loop, no freezing:

```bash
# terminal 1
.venv/bin/python -m uvicorn app.server:app --port 8000

# terminal 2
./build/dev.sh
```

The shell tries to spawn its sidecar, finds none, and falls back to port
8000. Frontend hot-reloads.

Or skip Tauri entirely and use the browser — `npm --prefix web run dev`.

## Where data lives

The installed app sits somewhere read-only, so models, sessions, the index
and logs go to a per-user directory:

| Platform | Path |
|---|---|
| Windows | `%LOCALAPPDATA%\IndustrialAIWorkbench` |
| macOS | `~/Library/Application Support/IndustrialAIWorkbench` |
| Linux | `~/.local/share/IndustrialAIWorkbench` |

In development it stays in the project folder. `backend_main.py` sets
`WORKBENCH_DATA_DIR` and `config.py` reads it.

## Ports

The shell binds port 0 to get a free one from the OS, passes it to the
backend, and the frontend asks for it via the `backend_port` command. Nothing
is hardcoded, so a user already running something on 8000 is unaffected.

## What breaks, and why

**PyInstaller misses imports.** uvicorn loads its protocol implementations by
string name, so static analysis never sees them. They are listed explicitly
in `backend.spec`. If you add a library that loads plugins dynamically, add
it there too — the failure shows up at runtime, not build time.

**Data files go missing.** `python-docx`, `python-pptx`, `openpyxl`, `pint`
and `sympy` all ship templates or tables that must be collected. Already
handled; the same applies to anything new.

**Sidecar name mismatch.** Tauri looks for `<name>-<target-triple>` and
refuses to bundle anything else. The build script derives the triple from
`rustc -vV`.

**Orphaned llama-server processes.** The backend detaches them deliberately so
they survive a backend restart, which means the shell has to kill them on
window close. It does. Without that, model weights stay in RAM after the app
closes and the next launch cannot bind its ports.

**Freeze early.** The freeze is the step most likely to eat a day. Run
`build/build.sh` once in the first week rather than the week of the demo.

## Server deployment

For the actual target — a GPU box in a plant or office — none of this
applies. Run the backend with uvicorn behind a reverse proxy and serve
`web/dist` as static files. Users reach it in a browser; nothing is installed
on their machines. The desktop installer is for demos and single-workstation
use.
