# Overview 
Socho is a platform for creating and distributing **behavioral research studies** online. Researchers (admins and managers) use a visual builder to compose study experiments from modular trial blocks. Participants access published studies, complete them in the browser, and their response data is recorded for export and analysis.

The platform is built around the **jsPsych** JavaScript framework — a widely used library for running behavioral experiments in the browser. Socho provides the no-code builder, participant management, data collection, and multi-tenancy on top of it.

## Typical Workflow

```mermaid
flowchart TD
    A[Researcher builds study\nin visual builder and publishes it] --> B[Study published\nto a Client org]
    B --> C[Participants in that org\naccess the study]
    C --> D[jsPsych runs the\nexperiment in browser]
    D --> E[Response data posted\nback to Socho]
    E --> F[Researcher downloads\nCSV export]
```


## Key Features and their Implementation Details

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
caption : sample trial structure

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
    DB->> JsGen :  
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

