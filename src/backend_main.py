#!/usr/bin/env python3
"""
Entry point for the frozen backend.

Tauri spawns this as a sidecar. It differs from `run.sh` in two ways that
matter once the app is packaged:

  - Data lives in a per-user directory, not next to the executable. A frozen
    app sits in Program Files or /Applications, where it cannot write.
  - The port can be passed in, so the shell can pick a free one rather than
    failing when 8000 is taken.
"""

import argparse
import os
import sys
from pathlib import Path


def data_dir() -> Path:
    """Per-user writable location for models, sessions, logs and the index."""
    if sys.platform == "win32":
        base = Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData/Local"))
    elif sys.platform == "darwin":
        base = Path.home() / "Library/Application Support"
    else:
        base = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    d = base / "IndustrialAIWorkbench"
    d.mkdir(parents=True, exist_ok=True)
    return d


def _prepend(var: str, path: str) -> None:
    current = os.environ.get(var, "")
    parts = [p for p in current.split(os.pathsep) if p]
    if path not in parts:
        os.environ[var] = os.pathsep.join([path, *parts])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8000)
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--data-dir", default=None)
    args = ap.parse_args()

    # config.py reads this before creating any directories, so it must be set
    # before the app package is imported.
    os.environ["WORKBENCH_DATA_DIR"] = args.data_dir or str(data_dir())

    # llama-server ships beside the frozen executable, and its shared
    # libraries ship as app resources. Without pointing the loader at them
    # the binary starts and immediately dies on a missing dylib.
    if getattr(sys, "frozen", False):
        bundled = Path(sys.executable).parent
        for name in ("llama-server", "llama-server.exe"):
            if (bundled / name).exists():
                os.environ.setdefault("LLAMA_SERVER", str(bundled / name))
                break

        for candidate in (bundled.parent / "Resources" / "lib",   # macOS .app
                          bundled / "lib",                        # Windows, Linux
                          bundled.parent / "lib"):
            if candidate.is_dir():
                lib = str(candidate)
                if sys.platform == "darwin":
                    # @rpath lookups fall back to this when the embedded
                    # rpath does not resolve, which is exactly our case.
                    _prepend("DYLD_FALLBACK_LIBRARY_PATH", lib)
                    _prepend("DYLD_LIBRARY_PATH", lib)
                elif sys.platform == "win32":
                    _prepend("PATH", lib)
                else:
                    _prepend("LD_LIBRARY_PATH", lib)
                print(f"library path: {lib}", flush=True)
                break

    import uvicorn
    print(f"data dir: {os.environ['WORKBENCH_DATA_DIR']}", flush=True)
    print(f"listening on http://{args.host}:{args.port}", flush=True)
    uvicorn.run("app.server:app", host=args.host, port=args.port,
                log_level="info", access_log=False)


if __name__ == "__main__":
    main()
