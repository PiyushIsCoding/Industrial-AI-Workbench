# Industrial AI Workbench — SIH 2026

Self-hosted agentic AI workbench that runs on local open-weight models. The system is designed to process documents and other inputs locally, use specialized agents and tools, and generate useful deliverables without sending model traffic to external services.

## 1. Project Information

- **Project Title:** Industrial AI Workbench
- **PS ID:** 26117
- **PS Title:** Sovereign On-Premise Agentic AI Workbench using Open-Weight Multimodal LLMs for Confidential Industrial Work
- **Category:** Software
- **Theme:** Smart Automation

 ### Team Info

| Team Member           | Role                                                    |
| --------------------- | ------------------------------------------------------- |
| **Suryansh Malhotra** | AI/ML — Model development, complex AI/ML implementation |
| **Dia Jainn**         | AI/ML — AI/ML implementation and integration            |
| **Arul Jain**         | AI/ML — AI/ML implementation and supporting tasks       |
| **Piyush**            | Frontend — UI development and application interface     |
| **Avani Agnihotri**   | Backend, PPT, Ideation & Demo                           |
| **Aditi Verma**       | Backend, PPT, Ideation, Demo & Editing                  |


## 2. Problem Statement

Refineries, PSUs, defence-linked manufacturing units and government offices generate a lot of routine but sensitive knowledge work. Approval notes, board presentations, engineering calculations, code for internal tools, review of scanned drawings and inspection reports.

None of this can go through cloud AI assistants like Claude or Codex because the underlying data is confidential: Piping & Instrument Diagrams, financials, vendor negotiations, unreleased designs, internal correspondence, confidential business strategies etc. Company policy keeps this data on premises, so people either do the work manually resulting in productivity gain, or they quietly paste confidential material into public tools anyway. Open weight large reasoning models have reached a point where a genuinely useful assistant built on them is realistic. But nothing deployable exists today that industrial users can actually work with the way they use Claude or Codex.

## 3. Proposed Solution

Industrial AI Workbench provides a local backend for agentic AI workflows using open-weight models. A request is first inspected deterministically, then a planner selects the appropriate agents, models, number of runs, parallelism, and fan-in strategy. The executor then mechanically carries out the plan.

Specialized agents handle tasks including vision, knowledge-base search, code generation, calculations, and document generation. Large content is written to disk and passed between workflow steps as file paths rather than being repeatedly placed into the planner's context.

The system supports local model management through `llama-server`, a local knowledge base, sandboxed code execution, document generation, citations, network monitoring, and activity auditing.

## 4. Key Features

- Approval notes
- Board presentations
- Word document generation
- Excel file generation
- Code generation for internal tools
- Sandbox execution and iteration
- Step-by-step calculations using SymPy
- Scanned PDF OCR
- Handwritten-note processing
- Engineering drawing analysis
- Photograph analysis
- Inspection-report generation
- Scoped P&ID analysis
- Multi-step planning
- Local tool calling
- Visible agent iteration
- Concurrent execution of multiple models
- Automatic model selection
- Extensible model management
- Local knowledge base with dense + BM25 search
- Fully local model traffic
- Document and page citations
- Network monitoring
- Activity/audit logs

## 5. Technology Stack

- **Backend:** Python, FastAPI
- **AI Runtime:** `llama-server` / llama.cpp
- **Models:** Local open-weight models
- **Database:** SQLite
- **Knowledge Base:** Hybrid dense + BM25 search with a JSON index
- **Document Processing:** PDF/image inspection and OCR through vision capabilities
- **Code Execution:** Docker sandbox with `--network=none` when Docker is available
- **Frontend/API Interface:** FastAPI API and `/docs`

## 6. Architecture

### Request Flow

```text
User Request
    |
    v
Intake
    |
    v
Planner
    |
    v
Router
    |
    v
Executor
    |
    +-----------------------------+
    |             |               |
    v             v               v
Vision         KB Agent        Code/Calc/
Agent          / Tools         Doc/Ppt/Xlsx
    |             |               |
    +-------------+---------------+
                  |
                  v
             Deliverable
                  |
                  v
       sessions/<id>/outputs/
```

### Component Structure

```text
src/app/
    config.py       paths, limits, and agent-to-capability map
    manifest.py     installed models and manifest enrichment
    supervisor.py   spawns llama-server, ports, health, and reaping
    router.py       model name to port with capability fallback
    llm.py          chat, vision, embedding, and reranking model client
    planner.py      decides agents, models, cardinality, parallelism, and fan-in
    executor.py     walks the plan without making planning decisions
    store.py        conversations, messages, and runs in SQLite
    audit.py        append-only event log
    netmon.py       outbound connection counter
    server.py       FastAPI application
    agents/         vision, RAG, code, calculation, and document agents
    rag/            knowledge-base indexing and retrieval
    tools/          intake, files, sandbox, and document generation
```

### How a Request Flows

```text
intake      deterministic file inspection, PDF→images
planner     one call: which agents, which models, how many, parallel?, fan-in
router      model name → port
executor    mechanical; spawns runs, gathers, passes forward
agents      one LLM + function tools; one input, one bounded output
deliverable file in sessions/<id>/outputs/
```

Bulk content does not travel between workflow steps. It is written to disk and passed as a path, keeping the planner's context small whether the system is processing one document or many.

## 7. Repository Structure

```text
workbench-v5/
├── README.md
├── requirements.txt
├── assets/
│   └── screenshots/             prototype screenshots and screenshots README
├── docs/
│   └── ARCHITECTURE.md         architecture documentation
├── src/
│   ├── backend_main.py
│   ├── BUILD.md
│   ├── engine.py
│   ├── hfcli.py
│   ├── run.sh
│   ├── smoke.py
│   ├── app/                    Python backend package
│   │   ├── agents/
│   │   ├── rag/
│   │   └── tools/
│   ├── web/                    React/Vite frontend
│   │   ├── package.json
│   │   └── src/
│   ├── src-tauri/              Tauri desktop shell
│   │   ├── build.rs
│   │   ├── Cargo.toml
│   │   ├── tauri.conf.json
│   │   ├── capabilities/
│   │   └── src/
│   └── build/                  packaging and development scripts
└── submission/
    ├── DEMO.md
    ├── PRESENTATION.md
    └── Orchestra_SIH26_PPT.pdf
```

### What goes where?

| Item | Location |
|---|---|
| Backend source code and CLI tools | `src/` and `src/app/` |
| Desktop application shell | `src/src-tauri/` |
| Frontend source code | `src/web/` |
| Build and development scripts | `src/build/` |
| Architecture / technical documentation | `docs/` |
| Project screenshots / prototype images | `assets/screenshots/` |
| Final PPT / presentation | `submission/` |
| Demo video link | `submission/DEMO.md` |
| Project overview | `README.md` |

## 8. Final Presentation

The final SIH presentation is available in [`submission/Orchestra_SIH26_PPT.pdf`](submission/Orchestra_SIH26_PPT.pdf).
It covers the problem, proposed solution, architecture, technology stack, feasibility, deployment, impact, and confidentiality considerations.

## 9. Demo Video

The demo video presents the Industrial AI Workbench, its self-hosted AI architecture, key features, workflow, and working prototype.

[Watch the demo video](https://drive.google.com/file/d/1qM05_gpofjU1eaWlxjrlZQPqz6C89zKX/view?usp=sharing)

## 10. Screenshots / Prototype Photos

The repository includes the following prototype screenshots:

- **Home:** Main application interface and entry point ([`01-home.png`](assets/screenshots/01-home.png))
- **Model Download:** Model browsing and download interface ([`02-model-download.png`](assets/screenshots/02-model-download.png))

## 11. Setup and Run

**Current packaged platform:** macOS

The application is currently available for macOS. A Windows version is also being built and will be supported in a future release.

Everything is bundled in the application — the interface, backend, and model runtime. No Python, Node.js, or other separate runtime installation is required.

### 1. Download

[Industrial AI Workbench](https://drive.google.com/file/d/1W7zniF--h7xmELXOxoGbG-80_CCEinws/view?usp=sharing) (macOS package)

### 2. Install

Open the `.dmg` file and drag **Industrial AI Workbench** into the Applications folder.

### 3. Clear the Quarantine Flag

The build is unsigned, so macOS may block it on the first launch. In Terminal, run:

```bash
xattr -cr "/Applications/Industrial AI Workbench.app"
```

Then open the application normally. This is a one-time step.

### 4. Add a Model

Launch the application and open the **Models** tab to download a model.

Each model is checked against the machine's available memory, so users can select models shown as a comfortable fit.

At least one text model is required. A vision model can be added for scanned documents, drawings, photographs, and handwriting, while an embedding model can be added for the knowledge base.

### Developer Setup

For development or running the backend directly from source, the following setup can be used:

```bash
python3 -m venv src/.venv
src/.venv/bin/python -m pip install -r requirements.txt
```

A local `llama-server`/llama.cpp installation is required when using the source-based backend workflow.

The backend can be started directly from the repository root with:

```bash
src/.venv/bin/python -m uvicorn --app-dir src app.server:app --host 127.0.0.1 --port 8000
```

For the desktop shell and installer, run the scripts from the repository root:

```bash
bash src/build/dev.sh       # development shell with hot reload
bash src/build/build.sh     # packaged installer
```

## 12. Get Models

Browse available models:

```bash
src/.venv/bin/python src/hfcli.py browse
```

Pull a model:

```bash
src/.venv/bin/python src/hfcli.py pull unsloth/Qwen3-VL-2B-Instruct-GGUF
```

Enrich the model manifest:

```bash
src/.venv/bin/python src/engine.py enrich
```

At least one text model is required. A vision model can be added for scanned documents, drawings, photographs, and handwriting. An embedding model can be added for the knowledge base.

## 13. Verify

Run the smoke test:

```bash
src/.venv/bin/python src/smoke.py
```

The smoke test checks the system layers without mocking the workflow.

## 14. Run

```bash
./src/run.sh
```

The application is served locally at:

```text
http://127.0.0.1:8000
```

API documentation is available at:

```text
http://127.0.0.1:8000/docs
```

## 15. Key API Endpoints

```text
GET  /api/models/browse?q=          Hugging Face catalogue
GET  /api/models/info/{repo_id}     card + quants with fit badges
POST /api/models/pull               download + enrich
POST /api/models/load/{repo_id}     start llama-server
DELETE /api/models/eject/{repo_id}  stop + delete

POST /api/chat/stream               SSE: plan, steps, done
POST /api/files/upload
GET  /api/files/deliverables/{sid}

POST /api/kb/ingest_upload
GET  /api/kb/search?q=

GET  /api/system/health
GET  /api/system/network            network/sovereignty counter
GET  /api/system/audit
GET  /api/system/agents
```

## 16. Scope Limits

- **P&ID:** Tag numbers, line numbers, and title block information are supported. Symbol classification and topology extraction are not attempted.
- **Handwriting:** Works on clear handwriting and may degrade on poor scans.
- **Sandbox:** Docker provides real isolation with `--network=none`. Without Docker, the system falls back to a subprocess, which provides weaker isolation.
- **Vector Store:** The current JSON index is suitable for demo-scale use. It can be replaced with Qdrant behind `kb.search()` as the corpus grows.

## 17. Future Scope

- Scale the knowledge base to larger industrial document collections.
- Replace the demo-scale JSON vector index with a production vector database such as Qdrant.
- Improve robustness for low-quality scans and difficult handwriting.
- Expand P&ID understanding beyond tags, line numbers, and title blocks.
- Extend the set of supported industrial workflows and specialized agents.
- Improve deployment and resource management for larger local model workloads.

