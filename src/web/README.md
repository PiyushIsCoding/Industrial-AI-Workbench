# Frontend

React + Vite + Tailwind. Dark, dense, built to read like an instrument panel
rather than a consumer chat app.

## Run

Backend first:

```bash
cd ..
./run.sh              # 127.0.0.1:8000
```

Then:

```bash
cd web
npm install
npm run dev           # 127.0.0.1:5173
```

Vite proxies `/api` to the backend, so there is no CORS setup and nothing
changes when this is later wrapped in Tauri.

## Views

**Workbench** — chat. Attach files by button or drag-drop. The plan appears
before execution and each step lights as it runs, showing the agent, the
model chosen for it, cardinality, and progress across parallel runs.
Deliverables collect in the right rail.

**Models** — installed list with load/unload/eject, and a Hugging Face
browser. Selecting a model shows its card and every quantization with a fit
badge checked against this machine's memory. Vision models pull their
projector file automatically.

**Knowledge** — ingest manuals and SOPs, search the index, see the document
and page each passage came from.

**System** — the external-connection counter, the agent roster with any
agent disabled for want of a model, and the activity log.

## Design notes

Colour is semantic, not decorative: green means running or clean, amber
means caution or a validation note, red means failure or an external
connection. Monospace is reserved for identifiers — model names, ports,
file paths, tag numbers, timestamps — so machine values are visually
distinct from prose.

## Build

```bash
npm run build         # -> dist/
```

`dist/` is what Tauri bundles.
