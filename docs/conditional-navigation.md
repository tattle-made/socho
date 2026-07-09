# Conditional Navigation in the Study Builder

Socho supports conditional branching and looping within survey/study flows using jsPsych's
built-in `conditional_function` and `loop_function` timeline options.

## How it works

jsPsych executes studies as a tree of **trial nodes** and **timeline nodes**. Branching is
achieved by attaching JS functions to **timeline nodes** that control whether the block runs
and whether it repeats. There is no "jump to" or "goto" — branching works by nesting blocks
and conditionally skipping them.

### `conditional_function` — skip a block

Evaluated once before the block starts. If it returns `false`, the entire block is skipped.

```js
const timeline = {
  timeline: [trial_a, trial_b],
  conditional_function: function() {
    const d = jsPsych.data.get().last(1).values()[0];
    return d.response === "yes"; // skip block if the last response wasn't "yes"
  }
};
```

### `loop_function` — repeat a block

Evaluated after each iteration of the block. Receives a `DataCollection` of all trials from
the just-completed iteration. If it returns `true`, the block runs again.

```js
const timeline = {
  timeline: [practice_trial],
  loop_function: function(data) {
    return data.select("correct").mean() < 0.8; // repeat until 80% accuracy
  }
};
```

Both functions are optional and independent — a timeline node can have one, both, or neither.

---

## Configuring it in the builder UI

### 1. Tag a trial (so you can reference it later)

Select a **trial node** in the builder. At the bottom of the Configure panel, under
**Identification**, enter a **Tag** value (e.g. `screening-question`).

This adds `data: { tag: "screening-question" }` to the generated jsPsych trial, which you
can then filter on in any condition function.

### 2. Add a condition to a timeline block

Select a **Timeline Group** node. At the bottom of the Configure panel, under
**Conditional Logic**, you will see two textareas:

- **Skip unless…** (`conditional_function`) — write a JS function body that returns `true`
  to run the block or `false` to skip it.
- **Repeat while…** (`loop_function`) — write a JS function body that returns `true` to
  repeat the block after each iteration.

Leave either field empty to disable that behaviour.

---

## Accessing previous trial data

Inside condition functions, use the `jsPsych.data` API:

```js
// Last trial's raw response
jsPsych.data.get().last(1).values()[0]

// Most recent trial (DataCollection wrapper)
jsPsych.data.getLastTrialData()

// All trials from the last completed timeline block
jsPsych.data.getLastTimelineData()

// Filter by a tag you set in the builder
jsPsych.data.get().filter({ tag: "screening-question" }).last(1).values()[0]

// Filter by jsPsych plugin type
jsPsych.data.get().filter({ trial_type: "survey-text" }).last(1).values()[0]

// Compute mean accuracy across a filtered set
jsPsych.data.get().filter({ tag: "practice" }).select("correct").mean()

// Custom predicate
jsPsych.data.get().filterCustom(t => t.rt > 1000).count()
```

### DataCollection methods

| Method | Returns | Description |
|---|---|---|
| `.last(n)` | `DataCollection` | Last n trials |
| `.first(n)` | `DataCollection` | First n trials |
| `.filter({ key: val })` | `DataCollection` | Equality filter; AND within object, OR across array |
| `.filterCustom(fn)` | `DataCollection` | Custom predicate `(trial) => boolean` |
| `.select("column")` | `DataColumn` | Single column with `.mean()`, `.sum()`, `.count()` etc. |
| `.values()` | `any[]` | Raw array of trial result objects |
| `.count()` | `number` | Number of trials in collection |

### Trial data fields

Each trial result always contains:
- `trial_type` — the plugin name (e.g. `"html-button-response"`)
- `trial_index` — global 0-based index
- `response` — participant's response (format varies by plugin)
- `rt` — reaction time in ms
- `correct` — boolean, if the plugin supports it
- `tag` — your custom tag, if you set one in the Identification section

---

## Example: screening question → conditional block

**Goal:** ask a consent/screening question, then show a follow-up block only if the
participant answered "Yes".

**Setup in the builder:**

1. Add a trial (e.g. `html-button-response`) with choices `["Yes", "No"]`.
   - Set its **Tag** to `consent`.
2. Add a **Timeline Group** containing the follow-up trials.
   - In **Skip unless…**, write:
     ```js
     const d = jsPsych.data.get().filter({ tag: "consent" }).last(1).values()[0];
     return d && d.response === "Yes";
     ```

**Generated output:**

```js
const trial1 = {
  type: jsPsychHtmlButtonResponse,
  data: { tag: `consent` },
  stimulus: `<p>Do you consent to participate?</p>`,
  choices: [`Yes`, `No`],
};

const timeline2 = {
  timeline: [trial3, trial4],
  conditional_function: function() {
    const d = jsPsych.data.get().filter({ tag: "consent" }).last(1).values()[0];
    return d && d.response === "Yes";
  },
};
```

---

## Example: practice block that repeats until accuracy threshold

**Goal:** repeat a practice timeline until the participant scores ≥ 80% correct.

**Setup in the builder:**

1. Create a **Timeline Group** with the practice trials inside.
2. In **Repeat while…**, write:
   ```js
   return data.select("correct").mean() < 0.8;
   ```
   (`data` is automatically available — it's the `DataCollection` from the last iteration.)

---

## Architecture notes for developers

### Storage

Both `conditional_function` and `loop_function` are stored as plain strings (JS function
bodies) in the timeline node's `config` map:

```elixir
%{
  "timeline_variables" => [...],
  "repetitions" => 1,
  "randomize_order" => false,
  "conditional_function" => "const d = jsPsych.data.get()...\nreturn d.response === \"yes\";",
  "loop_function" => ""
}
```

`data_tag` is stored in the trial node's `config` map under the key `"data_tag"`. It is
**not** a jsPsych plugin parameter — it is stripped from the plugin config during JS
generation and emitted separately as `data: { tag: ... }`.

### JS generation (`lib/socho/studies/js_generator.ex`)

- `timeline_config_to_js/1` — emits `conditional_function` and `loop_function` when
  non-empty, wrapping the stored body in `function() { ... }` / `function(data) { ... }`.
- `emit_node/2` (trial clause) — reads `config["data_tag"]`, removes it from config before
  calling `config_to_js/2`, and emits `data: { tag: \`...\` }` as a separate property.
- `indent_js_body/1` — indents each line of a multiline function body with 4 spaces for
  readable output.

### Builder (`lib/socho_web/live/study_live/builder.ex`)

- `add_timeline` initialises `"conditional_function"` and `"loop_function"` as `""`.
- `add_plugin_trial` initialises `"data_tag"` as `""`.
- `coerce_timeline_config/1` reads and trims both function body fields from form params.
- Trial `config_changed` events pass `data_tag` through `coerce_config/2` unchanged (it
  falls through the `_` case since it has no registry spec entry).

### Limitations

- **No jump/goto.** jsPsych has no mechanism to jump to an arbitrary point in the trial
  sequence. Branching must be modelled by nesting timeline blocks and skipping them.
- **`conditional_function` runs once at block start**, before any trials in the block. It
  cannot be based on data produced within the same block.
- **`loop_function` sees only the last iteration's data**, not the full experiment history.
  Use `jsPsych.data.get()` inside the loop function if you need history across iterations.
- Function bodies are stored and emitted verbatim — no validation or sandboxing is applied.
  Only admin/manager users with study edit access can set these.
