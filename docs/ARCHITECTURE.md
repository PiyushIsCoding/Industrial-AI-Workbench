# Architecture

A workflow with agents inside it.

The system is a fixed pipeline. Language models occupy specific stages within
it and are never asked to decide the shape of the pipeline itself. Ingestion,
document resolution, routing and execution are ordinary code that runs the
same way every time; the models decide only what to search for, what is
relevant, what to write, and how to word it.

This is the central design decision and it follows from the deployment
constraint. A general agent harness assumes a frontier model that plans freely
at runtime, holds enormous context and recovers from its own mistakes
mid-flight. On-premise hardware runs models an order of magnitude smaller,
which cannot do that reliably. So the intelligence moves from runtime to
design time: a closed roster of specialists, a plan produced once and
validated before execution, and mechanics carried out by code that does no
reasoning at all.

---

## Pipeline

```
SETUP PIPELINE                                    all deterministic
  A model is added
    ├─ S1  ACQUIRE      browse, fit-check, download weights
    ├─ S2  REGISTER     derive capability → manifest entry
    └─ S3  SERVE        spawn process, assign port, health-check

  A document is added
    └─ S4  INGEST       chunk → embed → store with page provenance

REQUEST PIPELINE
    ├─  1  INTAKE       classify files, render pages       code
    ├─  2  RESOLVE      which documents exist, and where   code
    ├─  3  PLAN         agents, order, cardinality, models model
    ├─  4  ROUTE        model name → port                  code
    ├─  5  EXECUTE      spawn runs, gather, pass forward   code
    │       └─ AGENTS   one model + function tools each    model
    ├─  6  COMPOSE      write or tighten the reply         model
    └─  7  DELIVER      files, citations, audit record     code

OBSERVERS (continuous)
       audit log · outbound connection counter
```

Eleven stages. Three use a model.

---

## Setup pipeline

Four stages, every one of them code. They run when something is added, not
when a request arrives, and the request pipeline assumes their output already
exists.

### S1 · Model acquisition · deterministic

Models are browsed, chosen and downloaded from inside the application. No
separate tool, no command line, no manual placement of files.

**Discovery.** The public model repository is queried over its open HTTP
interface, filtered to the runnable weight format. With no search term this is
the full catalogue by popularity; with one it is a keyword search. Selecting a
result retrieves the repository's file listing and its documentation, rendered
in the interface so the user reads the same description they would on the web.

**Fit checking.** A repository typically offers a dozen quantizations of the
same model and nothing on the page says which the machine can hold. Each
candidate is checked against usable memory — total, less what the operating
system and working set require — and marked comfortable, tight, or beyond
capacity. The largest comfortable option is recommended; anything beyond
capacity cannot be selected.

**Download.** One selection, one operation. The weight file is fetched along
with the documentation, which the next stage needs, and the vision projector
where one exists. Files land in a predictable per-model directory rather than
a content-addressed cache, so later stages locate them without consulting an
index.

### S2 · Model registration · deterministic

A downloaded file is inert until the system knows what it is. Capability is
derived on completion, from evidence rather than from the model's name:

- **Declared task type** from the model's own metadata — the publisher's
  statement of what it does.
- **Companion files on disk** — a projector beside the weights is harder
  evidence of vision capability than any prose description, because it is what
  the runtime actually requires.
- **Identifier conventions** — the ecosystem is consistent about marking
  specialised models, which resolves cases the metadata leaves ambiguous.

The output is a manifest entry: where the weights are, which companion files
exist, the licence, and the capability list. That entry is the model's entire
representation in the system. Nothing above this stage knows or cares what the
model is.

### S3 · Model serving · deterministic

Each model runs as its own supervised operating-system process, serving a
standard inference interface over a loopback port. This is the only component
in the system that knows anything about binaries, hardware or command-line
arguments — everything above it sees a port and a request format.

| Concern | Handling |
|---|---|
| **Port allocation** | Assigned from what is free and recorded, so several models coexist without collision and no port is fixed in advance. |
| **Capability flags** | Endpoint availability is not uniform. An embedding or reranking endpoint does not exist unless the process was started with the corresponding flag, and a multimodal model needs its projector passed at launch. Flags come from the manifest entry, so the right endpoints exist without anyone remembering to ask for them. |
| **Readiness** | Loading takes seconds for a small model and minutes for a large one on cold storage. A health endpoint is polled until the process answers, rather than waiting a fixed interval, and failure to load is reported distinctly from failure to respond. |
| **Detachment** | Model processes start in their own process group and survive a backend restart. Reloading weights on every code change would make development impractical and a backend crash far more costly than it needs to be. |
| **Reaping** | Because they are detached, they must be cleaned up deliberately. Dead entries are pruned from the runtime record on every inspection, and the desktop shell terminates every model process when its window closes. |
| **Output capture** | Each process writes to its own log, so a model that fails to load reports why rather than presenting as a generic timeout. |

**Concurrency.** Several models are resident simultaneously on distinct ports.
A plan moving from a reasoning model to a vision model to an embedding model
does so by addressing a different port, with no loading and no eviction
between steps.

**The uniform interface.** One component talks to model processes. Everything
else calls it by capability, never by address.

| Call shape | Used for | Note |
|---|---|---|
| Conversational | Reasoning, planning, writing, relevance judgement | Optionally with an output schema enforced during decoding |
| Multimodal | Reading images and rendered pages | Same endpoint as conversational; the request carries image content alongside text |
| Embedding | Converting text to vectors for retrieval | A distinct endpoint that exists only when the process was started for it |
| Reranking | Reordering retrieved passages by relevance | Optional; used when a suitable model is installed |

An agent states the capability it needs and, optionally, the model the planner
selected. Resolution to a port, starting the process if it is not running, and
substituting an alternative when the named model is unavailable all happen
beneath that call. No agent contains a port, a model name, or a hardware
assumption.

**Portability.** The same weight format and the same serving binary run on
datacentre accelerators, on desktop graphics hardware, on Apple Silicon, and
on processors alone. Detection happens once at startup and determines which
build is used and how much work is offloaded; nothing else in the system
observes the difference.

### S4 · Document ingestion · deterministic

Any document entering the system, by any route, is chunked and embedded on
arrival.

Splitting is section-aware: numbered clauses and headings become boundaries,
so a procedure is not cut mid-step, then each section is packed to a fixed
size with overlap so a sentence spanning a boundary survives intact in one
piece.

Every chunk carries its document name and page from the moment it is created.
That metadata travels through retrieval, through relevance filtering, into the
answer, and into any file generated from it. No stage is permitted to drop it.

---

## Request pipeline

Seven stages, run in this order on every request.

### 1 · Intake · deterministic

Each attachment is classified by inspection, not by asking a model. A document
carrying a text layer is read directly and indexed immediately; one without is
rasterised to page images for visual reading. Images are measured, and a large
sheet is marked for tiling because dense drawings lose their small annotations
when scaled to a model's input size.

The output is an inventory: what exists, of what kind, how many pages. File
contents are deliberately excluded — later stages need the shape of the input,
not its substance.

### 2 · Resolution · deterministic

The request is scanned for document references and each is matched against
what is attached and what is indexed. Matching is normalised so spacing, case
and a missing extension do not defeat it, and every candidate is checked
against live index contents rather than any fixed list.

The result is a verdict:

- which documents are indexed and searchable,
- which attachments must be read visually,
- and which references were named but exist nowhere.

This is handed to the planner as established fact, not as something to work
out.

### 3 · Planning · model

One call, before anything executes. The planner receives the request, the file
inventory, the resolution verdict, the roster of agents that can currently
run, and the catalogue of installed models. It emits a complete plan.

Per step it decides:

- **Which agent** — from a closed roster. It cannot invent one.
- **Which model** — chosen from what is actually installed, matched to the
  agent's required capability.
- **Cardinality** — one-to-one, one-to-many, many-to-many, or many-to-one.
- **Execution** — parallel or sequential, and how many at once. On a single
  accelerator, ten concurrent calls queue anyway while adding memory pressure.
- **Fan-in** — how several outputs are combined before the next step consumes
  them.

Output is constrained to a schema at decoding time, so a structurally invalid
plan cannot be produced. It is then validated in code: unknown agents are
rejected, references to undefined steps are dropped, and a model name that is
not installed is cleared so routing falls back on capability. Where validation
leaves nothing usable but the request plainly requires work, a minimal plan is
substituted.

The planner never writes search queries, never merges results and never writes
prose. Those belong to the stages that own them.

### 4 · Routing · deterministic

The plan names a model; routing returns a port, starting the model if it is
not already resident. Nothing else happens here — no task reasoning, no
substitution on quality grounds. If the named model is unavailable, one with
the required capability is used instead and the substitution is recorded.

### 5 · Execution · deterministic

The executor walks the plan and does exactly what it says. It reads the
declared cardinality, spawns that many agent invocations, respects the
parallel-or-sequential instruction and the concurrency ceiling, waits, and
assembles the results by the stated fan-in rule.

It makes no decisions. When many outputs feed one agent, assembly is
mechanical concatenation or grouping — there is no synthesis step, because
merging bounded structured outputs is assembly, not reasoning.

It enforces two invariants the agents cannot be trusted to maintain. Output
exceeding a size ceiling is written to disk and replaced by a reference, so
the planner's context stays constant whether the run processes two documents
or fifty. And citations are carried forward through every handoff, untouched.

#### The agent contract

Every agent has the same shape: one model, a small set of tools, one input,
one bounded output. Tools are ordinary functions — never another model, which
keeps the boundary between agent and tool unambiguous. An agent does not plan,
does not spawn another agent, and does not know the others exist.

| Agent | Responsibility |
|---|---|
| **General** | Answers and writes on any subject from model knowledge. Output is marked unsourced, so nothing downstream presents it as coming from the organisation's documents. |
| **Retrieval** | Four internal stages: the question is rewritten as two or three differently worded queries; each is embedded and searched sequentially, fusing vector similarity with keyword scoring; passages that mention the subject without answering are discarded; and the answer is written where the passages are, with inline citations. |
| **Vision** | Reads images and scanned pages in a single pass — text, tables, labels and description together. Tiles large drawings so small annotations stay legible. |
| **Code** | Writes code, runs it in an isolated sandbox with no network, reads any error, repairs and re-runs, bounded by an attempt limit. |
| **Calculation** | Generates the calculation as executable steps and runs it, so every printed figure was computed rather than asserted. |
| **Document** | Produces text documents, presentations and spreadsheets. The model supplies structured content; layout, typography and format are fixed by template, so no two outputs drift apart. |

#### Retrieval, in detail

Conventional retrieval searches once, with the user's exact wording. A
question phrased in everyday terms will not match a manual written in formal
ones closely enough to surface it. Four stages address that, in fixed order:

| Stage | Kind | What happens |
|---|---|---|
| Query expansion | model | The question is rewritten as two or three differently worded queries — synonyms, formal terminology, any identifier present in the question. The original wording always searches first, since a rewrite may be worse. |
| Search | code | Each query is embedded and searched. Dense vector similarity is fused with keyword scoring by reciprocal rank, because these documents are dense with tag numbers and clause references that embeddings handle poorly and exact matching handles well. Runs sequentially. Results merge and deduplicate. |
| Relevance filtering | model | Passages that mention the subject without answering the question are discarded. An empty result is a real verdict — the documents contain related material but nothing responsive. |
| Answering | model | The answer is written where the passages are, in prose, with inline citations. Each passage carries its citation immediately above it rather than in a separate legend, because matching numbered sources to text read earlier is a step small models get wrong. |

When resolution has already established which document a question concerns,
retrieval is scoped to it. Searching the remainder of the corpus at that point
adds only noise.

### 6 · Composition · model

The last stage before anything reaches the screen. Its behaviour depends on
what the run produced.

- **An answer already written** — from retrieval, where the passages were
  present — is edited only. Preamble and repetition are removed; every fact,
  figure and citation is left exactly as written. If editing removes more than
  half the length, the original stands, on the assumption the model rewrote
  rather than trimmed.
- **Generated content** passes through unchanged. There are no sources to
  check it against, so regenerating would only dilute it.
- **Agent output that is itself the answer** — a transcription, a calculation —
  is presented, reading full content back from disk where it was spilled.
- **A run that produced a file** gets a short closing note naming what was
  done and what was written, without restating the document's contents.

Output is checked for degeneration before it is shown. Small models given a
long or contradictory prompt fail characteristically — echoing the
instructions back, or repeating one sentence to the token limit. That output
looks like content and would otherwise flow into a deliverable. It is detected
by duplicate-line ratio, repeated phrase frequency and instruction echo;
salvaged where partial, rejected where not. A run that produces nothing usable
says so, rather than presenting noise.

### 7 · Delivery · deterministic

Generated files are written to the session's output directory and surfaced for
download. Citations gathered during the run accompany the reply, each naming
its source document and page. The full record of the run — the plan, every
step, every model and tool call — is retained and inspectable.

---

## Grounding

Different material carries different licence, and the constraint on each is
different.

| Material | Constraint |
|---|---|
| Extracted from organisational documents | Use only what is present. Add no background, recommendation or conclusion beyond it. Leave a field empty rather than filling it. A fabricated finding beneath a signature block is the failure this system exists to prevent. |
| Generated from model knowledge | Structure and preserve the substance. Reword for format, but introduce no figures, dates or claims that are not present. |
| Retrieved passages | Every statement must come from a passage, cited to document and page. Exact values are quoted, never rounded. Where the passages do not answer, say so. |

Provenance travels with the payload through every handoff, so a downstream
stage can tell generated material from extracted material and bind itself
accordingly.

---

## Observers

Two components watch every stage and participate in none. Neither is reachable
by an agent, and neither can be disabled from within a run.

**Audit record.** Append-only, one structured record per line. Every model
invocation, agent run, tool call, retrieval, file write and routing decision
is recorded with a timestamp and the session it belongs to. It can be tailed,
filtered and streamed to the interface without parsing the whole file.

**Egress counter.** An independent process polls the machine's outbound
connections, discards loopback, resolves the remainder and counts them. Model
traffic runs entirely on the loopback interface, so the count stays at zero
during operation. Connections made while acquiring models are counted
separately and shown as such rather than hidden — the distinction is visible
rather than argued.

---

## Technology stack

| Layer | Technology | Role |
|---|---|---|
| Model runtime | llama.cpp | Serves quantised models over an OpenAI-compatible interface. GPU acceleration on CUDA and Apple Silicon, CPU fallback elsewhere, from a single binary and weight format. |
| Weight format | GGUF | One artefact runs across every supported platform, so a model downloaded on one machine is usable on another. |
| Constrained decoding | Grammar-constrained generation | Structured output is enforced at decoding time rather than requested in a prompt, which is what makes planning viable on smaller models. |
| Backend | Python, FastAPI, Uvicorn | Asynchronous HTTP with server-sent events, so the plan and each step's progress reach the interface as they happen. |
| Retrieval | Hybrid dense and lexical | Vector similarity fused with keyword scoring by reciprocal rank. Local embedding and reranking models; no external service. |
| Persistence | SQLite, filesystem | Conversations, runs and audit records in an embedded database; artefacts and indexes on disk. No database server to operate. |
| Document generation | Open-source Office libraries | Word, presentation and spreadsheet files written directly from structured content against fixed templates. |
| Document intake | PDF text extraction and rasterisation | Text layers read directly; scanned pages rendered to images for visual reading; large sheets tiled. |
| Execution sandbox | Container isolation | Generated code runs with no network, no host filesystem access, dropped capabilities and capped memory and processor share. |
| Interface | React, Vite, Tailwind CSS | Single-page application showing the plan before execution, each step as it runs, model routing, deliverables and the egress counter. |
| Desktop shell | Tauri (Rust) | Native window and process lifecycle. Allocates a free port, starts the backend, terminates it and every model process on close. |
| Distribution | Frozen Python executable, platform installers | One installer per platform containing the interface, the backend and the model runtime. No runtime dependency installed by the user. |

---

## Deployment

Two forms, one codebase.

**Server.** The backend runs on the organisation's accelerated hardware and
the interface is served over the intranet. Nothing is installed on user
machines. This is the primary deployment.

**Workstation.** A single installer places the interface, the backend and the
model runtime on one machine. Application data lives in a per-user location,
since installed applications occupy read-only directories.

The same code runs on both. Capability is bounded by installed models, which
are a manifest entry rather than a code path — a site with more capable
hardware installs larger models and gets better output with no redeployment.

## Design principles

**Determinism where determinism is possible.** Classification, resolution,
routing, chunking, embedding and execution mechanics are code. Models are used
where judgement is genuinely required and nowhere else.

**Plan once, upfront.** The full plan is produced and validated before
execution and is visible before work begins. Decisions made one step at a time
are neither inspectable nor correctable.

**Bounded interfaces.** Every agent returns a size-limited structured result.
Bulk content moves through the filesystem. Context does not grow with
workload.

**Provenance is structural.** Source and page attach at ingestion and are
carried by the executor rather than by agent cooperation.

**Capability is configuration.** Models are manifest entries. Adding one
requires no code change and no restart.

**Fail visibly.** An honest failure is preferable to fluent output that is
wrong. Every stage that can produce unusable output is checked before that
output travels further.

---

All processing occurs on the deploying organisation's own hardware. Model
inference, embedding, retrieval, code execution and document generation are
local. No document content, query or generated artefact is transmitted beyond
the machine.
