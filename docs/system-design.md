# System Design — Socho

This document is for developers new to the Socho codebase. It covers what the platform does, how it is structured, and how the main features work end-to-end.

---

## Table of Contents

1. [What is Socho?](#what-is-socho)
2. [Tech Stack](#tech-stack)
3. [Architecture Overview](#architecture-overview)
4. [Domain Model](#domain-model)
5. [Directory Structure](#directory-structure)
6. [Key Features](#key-features)
   - [Study Builder](#study-builder)
   - [Study Participation](#study-participation)
   - [Plugin & Registry System](#plugin--registry-system)
   - [Authentication & Authorization](#authentication--authorization)
   - [Data Export](#data-export)
7. [Frontend & JavaScript Interop](#frontend--javascript-interop)

---

## What is Socho?

Socho is a platform for creating and distributing **behavioral research studies** online. Researchers (admins and managers) use a visual builder to compose study experiments from modular trial blocks. Participants access published studies, complete them in the browser, and their response data is recorded for export and analysis.

The platform is built around the **jsPsych** JavaScript framework — a widely used library for running behavioral experiments in the browser. Socho provides the no-code builder, participant management, data collection, and multi-tenancy on top of it.

**Typical workflow:**

```mermaid
flowchart LR
    A[Researcher builds study\nin visual builder] --> B[Study published\nto a Client org]
    B --> C[Participants in that org\naccess the study]
    C --> D[jsPsych runs the\nexperiment in browser]
    D --> E[Response data posted\nback to Socho]
    E --> F[Researcher downloads\nCSV export]
```

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Elixir ~> 1.15 |
| Web framework | Phoenix 1.8 |
| Real-time UI | Phoenix LiveView ~> 1.1 |
| Database | PostgreSQL (via Ecto) |
| CSS | Tailwind CSS v4 |
| JS bundler | esbuild |
| Experiment runtime | jsPsych (npm) |
| Rich text editing | TipTap (in survey builder) |
| Authentication | bcrypt + session tokens |
| Email | Swoosh |

---

## Architecture Overview

Socho follows a standard Phoenix layered architecture with LiveView for the interactive builder UI. The study execution layer is entirely client-side jsPsych — Socho generates the JavaScript, serves it, and collects results.

```mermaid
flowchart TB
    subgraph Browser
        LV[Phoenix LiveView\nBuilder UI]
        JS[jsPsych Runtime\nExperiment Player]
    end

    subgraph Phoenix App
        Router
        Controllers
        LiveViews
        Contexts[Business Logic\nContexts]
        JsGen[JS Generator]
    end

    subgraph PostgreSQL
        Studies[(studies)]
        Trials[(trials)]
        Submissions[(submissions)]
        Users[(users)]
    end

    Browser -->|WebSocket| LiveViews
    Browser -->|HTTP| Controllers
    LiveViews --> Contexts
    Controllers --> Contexts
    Contexts --> PostgreSQL
    JsGen -->|Generated JS| JS
    JS -->|POST response data| Controllers
```

---

## Domain Model

```mermaid
erDiagram
    CLIENT {
        uuid id
        string name
    }
    USER {
        uuid id
        string email
        string hashed_password
        enum role
        uuid client_id
    }
    STUDY {
        uuid id
        string title
        string description
        enum status
        uuid client_id
    }
    TRIAL {
        uuid id
        uuid study_id
        uuid parent_id
        string plugin
        string node_type
        int position
        jsonb config
        jsonb extensions
    }
    SUBMISSION {
        uuid id
        uuid study_id
        uuid user_id
        jsonb data
    }

    CLIENT ||--o{ USER : "has participants"
    CLIENT ||--o{ STUDY : "owns"
    USER ||--o{ SUBMISSION : "submits"
    STUDY ||--o{ TRIAL : "contains"
    TRIAL ||--o{ TRIAL : "parent_id (nesting)"
    STUDY ||--o{ SUBMISSION : "receives"
```

### Key entities

**User** — Has one of three roles: `admin`, `manager`, or `participant`. Managers and participants are scoped to a `Client` organisation.

**Client** — An organisation/tenant. Participants belong to a client and can only take studies published for that client.

**Study** — A research experiment. Has a `status` of `draft` or `published`. Contains an ordered tree of `Trial` nodes.

**Trial** — A single task or container. The `plugin` field names the jsPsych plugin to use (e.g. `"survey-likert"`). The `config` JSONB field stores plugin parameters. `node_type` is one of:

| node_type | Description |
|-----------|-------------|
| `trial` | A single jsPsych task |
| `timeline` | A container that groups child trials and can set timeline variables, repetitions, or loop functions |
| `counterbalanced_group` | Randomises the order of child timelines across participants |
| `template_group` | A reusable preset defined in code (not persisted as individual children) |

**Submission** — One per (study, participant) pair. The `data` field holds the raw jsPsych event array.

---

## Directory Structure

```
socho/
├── assets/
│   ├── css/                        Tailwind styles
│   ├── js/
│   │   ├── app.js                  LiveView setup, hook registration
│   │   └── sortable_hook.js        Drag-drop for trial tree
│   ├── custom_plugins/             Custom jsPsych plugins
│   │   ├── example-rating/
│   │   ├── image-swipe/
│   │   └── multi-image-select/
│   └── setup_jspsych.mjs           Build script: generates plugin registries
│
├── config/                         Phoenix configuration
├── lib/
│   ├── socho/                      Business logic (contexts & schemas)
│   │   ├── accounts/               Users, sessions, auth
│   │   ├── clients/                Client organisations
│   │   ├── studies/
│   │   │   ├── study.ex
│   │   │   ├── trial.ex
│   │   │   ├── submission.ex
│   │   │   ├── registry.ex         Plugin metadata loader
│   │   │   ├── js_generator.ex     Generates jsPsych JS from trial tree
│   │   │   ├── templates.ex        Pre-built study templates
│   │   │   └── studies.ex          Main context (queries, save, export)
│   │   └── app_settings/
│   │
│   └── socho_web/                  Web layer
│       ├── controllers/
│       │   ├── study_controller.ex Study player + data submission endpoint
│       │   └── user_session_controller.ex
│       ├── live/
│       │   ├── study_live/
│       │   │   ├── builder.ex      Visual study builder (LiveView)
│       │   │   ├── builder_components.ex
│       │   │   ├── survey_builder_component.ex
│       │   │   ├── dashboard.ex    Participant study list
│       │   │   ├── index.ex        Admin study list
│       │   │   └── settings.ex     Study metadata editor
│       │   └── user_live/
│       ├── components/             Reusable HEEx components
│       ├── user_auth.ex            Auth plugs
│       └── router.ex
│
└── priv/
    ├── jspsych_registry.json       Auto-generated (npm plugins)
    ├── custom_plugins_registry.json Auto-generated (custom plugins)
    └── repo/migrations/
```

---

## Key Features

### Study Builder

The builder is a Phoenix LiveView (`builder.ex`) that gives researchers a three-column layout: trial tree on the left, config panel in the middle, and a live preview on the right.

#### Data Flow — Editing a Trial

```mermaid
sequenceDiagram
    participant User as Researcher
    participant LV as Builder LiveView
    participant DB as PostgreSQL

    User->>LV: Select trial in tree
    LV->>LV: assign selected_trial_id
    LV->>User: Render config panel for trial

    User->>LV: Change a config field (phx-change)
    LV->>LV: handle_event("config_changed")<br/>update trials tree in assigns

    User->>LV: Click "Save"
    LV->>DB: Studies.update_study_with_trials()<br/>(transaction: delete old trials, insert new tree)
    DB->>LV: {:ok, study}
    LV->>User: Flash "Saved"
```

#### Trial Tree Structure

Trials are stored flat in the database with a `parent_id` column. When loaded, they are assembled into a nested tree in memory. The builder works on this in-memory tree and writes it back on save.

```mermaid
flowchart TD
    Root[Study root]
    Root --> T1[Timeline: Instructions]
    Root --> T2[Timeline: Main task]
    Root --> T3[Trial: Debrief]
    T2 --> T2A[Trial: Fixation cross]
    T2 --> T2B[Trial: Stimulus]
    T2 --> T2C[Trial: Response]
```

#### Survey Builder Component

Survey-type trials (survey text, survey likert) have a richer editor provided by `SurveyBuilderComponent` (a LiveComponent). It maintains its own question list in state and synchronises with the parent builder via a `notify_parent` message pattern — it never submits the survey JSON as a form field.

```mermaid
sequenceDiagram
    participant User
    participant SC as SurveyBuilderComponent
    participant BLD as Builder LiveView

    User->>SC: Toggle "Required" checkbox
    SC->>SC: handle_event("sq_toggle_required")<br/>update questions in assigns
    SC->>BLD: send(self(), {:survey_builder_update, json})
    BLD->>BLD: handle_info → update trials[id].config.survey_json
    BLD->>SC: update/2 called (parent re-render)<br/>survey_json preserved in server state
```

#### Live Preview

The builder can render the study inline without saving. `JsGenerator.generate_inline_js/1` builds a full jsPsych script from the current in-memory trial tree and injects it into an iframe. The iframe uses `?preview=true` which suppresses data submission.

---

### Study Participation

Participants access studies through a conventional HTTP controller (`StudyController`), not LiveView. The page is a minimal HTML shell; jsPsych owns the entire page once loaded.

#### Sequence Diagram — Taking a Study

```mermaid
sequenceDiagram
    participant P as Participant browser
    participant SC as StudyController
    participant JsGen as JsGenerator
    participant DB as PostgreSQL
    participant jsPsych as jsPsych (browser JS)

    P->>SC: GET /studies/:id
    SC->>DB: Fetch study + trials
    SC->>JsGen: required_scripts(study)
    SC->>JsGen: generate_inline_js(study)
    SC->>P: HTML page with <script> tags

    Note over P,jsPsych: Browser loads scripts
    P->>jsPsych: Initialise with generated timeline
    jsPsych->>P: Display trials in sequence

    Note over jsPsych: Participant completes all trials
    jsPsych->>SC: POST /studies/:id/user-data<br/>{ trials: [...jsPsych event objects] }
    SC->>DB: Studies.record_submission()
    SC->>jsPsych: { status: "ok" }
    jsPsych->>P: Show completion screen
```

#### JS Generation

`JsGenerator` (`lib/socho/studies/js_generator.ex`) translates the trial tree into jsPsych JavaScript:

```mermaid
flowchart LR
    Tree[Trial tree\nin Elixir] --> Gen[js_generator.ex]
    Registry[Plugin registry\nJSON] --> Gen
    Gen --> Scripts["&lt;script src=...&gt; tags\nper plugin"]
    Gen --> Inline["Inline JS:\njsPsych.run({timeline: [...]})"]
```

Each trial node becomes a jsPsych timeline entry. Timelines, loops, and conditional skip logic (`skip_unless`) are translated to jsPsych's `conditional_function` and `loop_function` options.

---

### Plugin & Registry System

jsPsych plugins are the building blocks for trials. Socho loads plugin metadata from two sources at build time and makes it available to the builder at runtime.

#### Build-time Registry Generation

```mermaid
flowchart TD
    NPM[npm packages\n@jspsych/plugin-*] --> Setup[setup_jspsych.mjs]
    Custom[assets/custom_plugins/*] --> Setup
    Setup --> JR[priv/jspsych_registry.json]
    Setup --> CR[priv/custom_plugins_registry.json]
    JR --> Reg[Socho.Studies.Registry]
    CR --> Reg
    Reg --> Builder[Builder LiveView\nshows available plugins]
    Reg --> JsGen[JsGenerator\nselects required scripts]
```

#### Plugin Metadata

Each plugin entry in the registry describes its parameters:

```json
{
  "survey-likert": {
    "name": "survey-likert",
    "parameters": {
      "questions":   { "type": "COMPLEX", "array": true },
      "scale_width": { "type": "INT" },
      "randomize_question_order": { "type": "BOOL" }
    }
  }
}
```

The builder reads these parameters and dynamically renders the correct input widget for each type (`INT` → number input, `BOOL` → checkbox, `HTML_STRING` → rich text editor, etc.).

#### Adding a Custom Plugin

1. Create a directory under `assets/custom_plugins/<plugin-name>/`
2. Add an `index.js` exporting a jsPsych plugin and a `registry.json` describing its parameters
3. Run `mix assets.setup` to regenerate `custom_plugins_registry.json`
4. The plugin appears automatically in the builder

---

### Authentication & Authorization

#### Authentication Flow

```mermaid
sequenceDiagram
    participant U as User browser
    participant Auth as UserSessionController
    participant DB as PostgreSQL

    U->>Auth: POST /users/log_in (email + password)
    Auth->>DB: Accounts.get_user_by_email_and_password()
    DB->>Auth: User record
    Auth->>Auth: Bcrypt.verify_pass()
    Auth->>DB: Accounts.generate_user_session_token()
    DB->>Auth: session token
    Auth->>U: Set encrypted cookie + redirect

    Note over U,Auth: Subsequent requests
    U->>Auth: Request with cookie
    Auth->>DB: Accounts.get_user_by_session_token()
    DB->>Auth: User
    Auth->>Auth: Build Scope struct
    Auth->>U: Request proceeds
```

#### Role-Based Access

There are three roles. Every request passes through a `Scope` struct that carries the current user and their client context.

```mermaid
flowchart TD
    Request --> FetchScope[fetch_current_scope_for_user plug]
    FetchScope --> Role{User role?}
    Role -->|admin| AdminRoutes[All studies, all users,\nall clients, app settings]
    Role -->|manager| ManagerRoutes[Studies for their client,\nparticipants for their client]
    Role -->|participant| ParticipantRoutes[Dashboard:\npublished studies for their client]
    Role -->|unauthenticated| PublicRoutes[Login, register,\nmagic link]
```

#### Study Access Guard

When a participant loads a study, `StudyController` verifies their client matches the study's client before serving the page:

```mermaid
flowchart LR
    P[Participant\nclient_id = X] --> Check{study.client_id\n== X?}
    Check -->|yes| Serve[Serve study page]
    Check -->|no| Forbidden[403 Forbidden]
```

---

### Data Export

After a study runs, submissions are stored as raw jsPsych event arrays. Socho can export them as a flat CSV.

```mermaid
flowchart LR
    Submissions[submissions table\ndata JSONB] --> Export[Studies.export_submissions_csv]
    Export --> Flatten[Flatten trial arrays\nper submission]
    Flatten --> Headers[Derive column headers\nfrom all trial keys]
    Headers --> CSV[CSV file\ndownloaded by researcher]
```

Each row in the CSV is one submission. Columns are derived from the union of all jsPsych event keys across all submissions (e.g. `rt`, `response`, `stimulus`, `trial_type`). Trial-level columns are prefixed by trial index when a submission has multiple trials.

---

## Frontend & JavaScript Interop

### LiveView Hooks

Hooks connect DOM elements to JavaScript behaviour while letting the server stay in control of state. The main hooks in use:

| Hook | File | Purpose |
|------|------|---------|
| `Sortable` | `sortable_hook.js` | Drag-and-drop reordering of trials in the builder tree |
| `.SurveyHtml` | (colocated in component) | TipTap rich text editor for survey question titles; pushes `sq_update_field` events to the server on blur |

### phx-update="ignore"

The TipTap editor elements use `phx-update="ignore"` so LiveView does not overwrite the editor's DOM on re-renders. The editor is initialised once by the hook and manages its own DOM. Data flows back to the server via `phx-hook` push events, not by LiveView patching the element.

### jsPsych ↔ Socho Communication

jsPsych runs completely independently of LiveView. The only communication between jsPsych and the Phoenix backend is a single HTTP POST at the end of the study:

```mermaid
sequenceDiagram
    participant jsPsych
    participant Phoenix

    jsPsych->>jsPsych: onFinish callback fires
    jsPsych->>Phoenix: POST /studies/:id/user-data<br/>Content-Type: application/json<br/>Body: { trials: [...] }
    Phoenix->>Phoenix: Validate CSRF token
    Phoenix->>Phoenix: Check not already submitted
    Phoenix->>Phoenix: Upsert submission record
    Phoenix->>jsPsych: { status: "ok" }
```
