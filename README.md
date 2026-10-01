# System Legos

A macOS flashcard course for mastering system design, built on the same app layout as
Sloka Words (`~/code/sloka_words`). Modern system design is like building with LEGO: instead of
manufacturing every screw and beam, you snap together standardized, high-performance
components through well-defined interfaces. Every card gives the LEGO view of a piece, what
it really is, when to reach for it, how it breaks, and links to the blogs and papers worth
reading in depth.

## The course

| Module | Groups | Cards |
| --- | --- | --- |
| 1 · The Bricks | Compute (VMs, containers, orchestration, serverless) · Storage (relational, NoSQL, object storage, Cassandra and its wide-column cousins, distributed SQL, search, vector DBs, ZooKeeper/etcd, Google Cloud Storage buckets) · Networking (DNS, load balancers, API gateways, CDNs, Istio, Torbit) · Integration (queues, streams, caches, Kafka deep dive, distributed cache) · Observability (Prometheus, tracing) | 26 |
| 2 · Building Rules | Scaling (vertical vs horizontal, statelessness, replication, sharding, consistent hashing) · Data (CAP/PACELC, consistency models, caching patterns, sagas and outbox, ID generation) · Reliability (idempotency, retries and jitter, circuit breakers, rate limiting, load shedding, delivery semantics) · Numbers (latency, estimation, SLOs) | 19 |
| 3 · Assemblies | Worked examples: Uber-like ride hailing, flash-sale checkout · Classic builds: URL shortener, news feed, chat, video streaming, rate limiter, notifications | 8 |
| 4 · Master Builder Path | Step 1 Trace the Blueprints (primers, Alex Xu, DDIA, Netflix, Uber, Airbnb, Segment, SRE) · Foundational papers (GFS, MapReduce, Bigtable, Dynamo, the Log/Kafka, Spanner, Raft/Paxos, Memcache, Tail at Scale) · Step 2 Virtual CAD (tools, traffic-flow mapping, the 45-minute framework) · Step 3 Mini-MOCs (URL shortener, thumbnail generator, order queue) · Step 4 Break Your Models (chaos engineering and five drills) | 29 |
| 5 · Data & Batch Pipelines | Streaming (stream processing with Flink/Spark/Dataflow, CDC, Lambda vs Kappa) · Batch & lakehouse (Apache Spark, Airflow orchestration, Iceberg/Delta/Hudi, Parquet and BigQuery, batch design principles) · Pipeline builds (daily batch ETL, real-time clickstream, bad-data and backfill drill) | 11 |
| 6 · ML Platform & LLM Serving | ML platform (feature store, MLflow, Ray, ML pipelines) · Online large-model serving (inference fundamentals, continuous batching and PagedAttention, vLLM, SGLang, Triton, prefix caching and KV-aware routing, parallelism, quantization, speculative decoding, disaggregated prefill/decode, Kubernetes serving and GPU autoscaling, AI gateway, multi-LoRA serving, structured output, token streaming, inference caching) · Online inference case studies (code completion, thousands of LoRA fine-tunes, payment fraud scoring, semantic search, agentic assistant, real-time voice, giant MoE serving, multi-region LLM API, inline guardrails, prefix-aware router Mini-MOC, bad-model and noisy-tenant drill) · ML builds (LLM serving platform, real-time recommendations, batch LLM inference, RAG assistant, training-to-deploy, vLLM Mini-MOC, GPU chaos drill) | 38 |

That is 91 **brick** cards (single concepts) and 40 **build** cards (assemblies, projects
and chaos drills), with about 425 reading links.

## Build and run

Requires macOS 14 or later and the Xcode Command Line Tools (`xcode-select --install`).

```sh
./scripts/build_app.sh
open build/SystemLegos.app
```

For development you can also run `swift run --package-path app`.

## Phone and web app

`web/` holds an installable, offline-capable web app (plain HTML, CSS and JavaScript) with the
same cards, laid out for phones like Sloka Words: Bricks/Builds and Learn/Test switches,
swipe between cards, tap to reveal, Known/Review marks, a drawer for modules and options,
notes with a Markdown build-journal export, brick peeks, and print or save as PDF.

It is published with GitHub Pages from the `main` branch at
<https://venkatacrc.github.io/systemlegos/> (the root `index.html` redirects to `web/`). On a
phone, open it once online, then use **Add to Home Screen** (iOS Safari: Share → Add to Home
Screen; Android Chrome: ⋮ → Install app). After that it works offline.

`python3 tools/build_deck.py` writes `web/deck.json` alongside the Mac app's deck, so
commit and push after editing the course to update the web app. To try it locally:

```sh
python3 -m http.server 8000   # then open http://localhost:8000/web/
```

Progress, notes and preferences are saved in the browser's local storage. **Back up notes**
in the menu downloads them as `notes.json`, the same format as the Mac app's
`~/Library/Application Support/SystemLegos/notes.json`, and **Import notes** reads either file.
To regenerate the icons, run `swift scripts/make_icon.swift --web web/icons`.

## Using the app

- **Bricks / Builds** (top left of the toolbar): practice single concepts, or whole
  assemblies.
  - A brick card shows the name, real-world examples and its LEGO view. Say what it is,
    when you'd reach for it and how it breaks, then press **Space** to check.
  - A build card shows the problem. Sketch the assembly (which bricks, in what order and
    why), then press **Space** to see the numbered steps, the bricks it snaps together, the
    reasoning, the numbers, and the ways to break it. Click a brick chip to see a summary
    of that brick without leaving the card.
  - Each brick lists the builds that use it, and each card links to what to read next.
- **Learn / Test** (toolbar):
  - *Learn* shows every card in full. Step through with **← / →**, and mark cards with
    **K** (known) or **R** (review).
  - *Test* hides the answer. Recall it, press **Space** to reveal, then **G** (got it) or
    **M** (missed it). At the end you see your score and can retest just the missed cards.
- **Notes (N):** keep your own notes on any card: a mnemonic, a gotcha, or for projects and
  drills, what you built, what broke and how you patched it. **File → Export Build
  Journal…** (⇧⌘E) writes all notes to a Markdown file.
- **Print** (⌘P): prints the cards in the ticked groups as a study guide, or saves it as a
  PDF, with optional details, links and notes, and optionally only cards marked for review.
- **Sidebar:** tick the modules and groups to practice. Your choices are saved.
- **Toolbar:** *All cards*, *Not yet known* or *Review only*; **Shuffle**; **Restart**.
- **File menu:** **Import Deck…** (⌘O), **Reload Deck** (⇧⌘R), **Use Built-in Deck**,
  **Reset Progress…**.

Progress is saved per card id, so adding cards keeps your known and review marks. Notes are
stored in `~/Library/Application Support/SystemLegos/notes.json`.

## Suggested study plan

1. **Weeks 1–2:** Learn mode through *The Bricks* and *Building Rules*, one group a day.
   Test yourself on the previous day's group before starting a new one.
2. **Weeks 3–4:** *Assemblies* in Test mode. For each build, sketch it in Excalidraw before
   revealing, then note what you missed.
3. **Alongside:** one blueprint or paper from *Step 1* a week. Put your summary in the
   card's notes.
4. **Weeks 5–8:** build the *Step 3* Mini-MOCs on a free tier, then run every *Step 4* drill
   against them. Record each experiment's hypothesis, result and fix in the notes, and
   export the journal.

## Editing the course

The course lives in `course/` as JSON: `modules.json` (sidebar modules and groups) and one
file of cards per module. After editing, rebuild the deck:

```sh
python3 tools/build_deck.py               # validates and writes the app's deck.json
python3 tools/build_deck.py --check-links # also requests every reading link
```

The builder checks that ids are unique, every card's module and group exist, builds have
steps, every `uses` entry names a real card, and links are https with a known kind. Then
rebuild the app, or load `app/Sources/SystemLegos/Resources/deck.json` with **Import Deck…**.

### Card fields

| Field | Meaning |
| --- | --- |
| `id` | Unique id; progress and notes are keyed by it |
| `kind` | `brick` (concept) or `build` (assembly, project or drill) |
| `module`, `group` | Where it appears in the sidebar |
| `title`, `subtitle` | Name, and real-world examples or authors |
| `lego` | The LEGO analogy shown on the front |
| `summary` | What it is (bricks), or the problem (builds) |
| `steps` | The ordered assembly (required for builds) |
| `uses` | Ids of the bricks and rules a build snaps together |
| `sections` | Titled bullet lists: when to use, trade-offs, how it breaks, drills… |
| `links` | `{title, url, kind, note}`; `kind` is `paper`, `blog`, `docs`, `book`, `talk`, `tool` or `course` |

## Layout

```
app/                   Swift package (SwiftUI app)
  Sources/SystemLegos/Resources/deck.json   generated deck bundled into the app
course/                course content (source of truth)
tools/build_deck.py    validates course/ and writes deck.json (app and web)
web/                   phone and web app (PWA) served by GitHub Pages
index.html             redirects the Pages site root to web/
scripts/build_app.sh   builds build/SystemLegos.app
scripts/make_icon.swift draws the LEGO-brick icon (Mac iconset, or --web PNGs)
```
