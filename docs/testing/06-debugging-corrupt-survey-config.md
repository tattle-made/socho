# Debugging Guide: Corrupt or Missing Survey Configuration in the Builder

This guide documents how to diagnose and fix cases where a survey block shows empty configuration in the study builder, even though the participant-facing preview works correctly.

---

## Symptom

- Clicking a survey trial block in the builder shows no questions in the config panel.
- The participant-facing preview (or live study) renders the survey correctly.
- No error is shown to the user — the config panel just appears empty or shows "No configurable parameters."

---

## How Survey Config Flows Through the System

Understanding the two separate paths helps isolate where the break is:

```
Preview path:  DB trial.config → js_generator.ex → embedded JS → participant browser
Editor path:   DB trial.config → builder assigns → param_field → SurveyBuilderComponent.update/2 → UI
```

The preview path reads `config["survey_json"]` directly and embeds it as JSON in the generated JS — it never goes through the builder's deserialization logic. This is why a broken editor path does not affect the preview.

---

## Layer 1: Is the "survey" Plugin in the Registry?

The builder renders parameter fields only for parameters listed in the plugin registry (`priv/jspsych_registry.json`). If the `"survey"` entry is missing, the config panel shows nothing — regardless of what is in the database.

**Check:**
```bash
node -e "const fs=require('fs'); const d=JSON.parse(fs.readFileSync('priv/jspsych_registry.json')); console.log(d['survey'] ? 'PRESENT' : 'MISSING')"
```

**Why this happens:**
`node assets/setup_jspsych.mjs` regenerates `priv/jspsych_registry.json` from scratch. The `@jspsych/plugin-survey` package crashes when imported in Node.js (it calls `window.addEventListener` at import time), so its entry is silently skipped. The script now has a hardcoded fallback to prevent this, but if you downgrade or modify the script you may lose it.

**Fix:**
Re-run the setup script — the fallback will restore the entry:
```bash
node assets/setup_jspsych.mjs
```

Or manually verify the entry is present and contains `survey_json` with `"type": "OBJECT"`.

---

## Layer 2: Is the Data Actually in the Database?

If the registry is fine but the editor still shows empty config, confirm the data exists in the DB.

**Check via iex:**
```elixir
alias Socho.Repo
alias Socho.Studies.Trial

# Replace with the actual study ID (visible in the URL: /studies/:id/edit)
study_id = 123

Trial
|> Ecto.Query.where([t], t.study_id == ^study_id and t.plugin == "survey")
|> Repo.all()
|> Enum.map(fn t -> {t.id, t.config["survey_json"]} end)
```

**Expected:** Each survey trial returns a map like:
```elixir
{42, %{"elements" => [...], "completeText" => "Next"}}
```

**Bad signs:**
- `survey_json` is `nil` or `%{}` → the config was never saved or was overwritten with empty JSON.
- `survey_json` is a JSON string instead of a decoded map → the `:map` Ecto field type handles decoding, so this should not happen, but worth confirming.

---

## Layer 3: Is `parse_survey_json` Receiving the Right Value?

Even if the DB has correct data, the builder's in-memory state could diverge. Add a temporary debug log in `survey_builder_component.ex`:

```elixir
def update(%{value: value, field_name: field_name} = assigns, socket) do
  IO.inspect(value, label: "survey_builder value")   # <-- temporary
  ...
```

Then open the builder and click a survey block. Look at the server log for the inspected value.

**If value is `nil` or `%{}`:** The config key is missing or was overwritten in the builder's in-memory state. This can happen if `notify_parent` fired before the correct config was parsed (e.g., if a previous bug caused empty questions to be sent back to the builder).

**If value is a proper map with `"elements"`:** The issue is in `element_to_question` — check whether any of the element types crash silently.

---

## Layer 4: Is `element_to_question` Failing on a Specific Question Type?

If `parse_survey_json` receives a valid map but returns empty questions, an unhandled question type is falling through to an unexpected clause. Add a log:

```elixir
defp parse_survey_json(%{"elements" => els} = json) when is_list(els) do
  IO.inspect(els, label: "elements to parse")   # <-- temporary
  %{
    questions: Enum.with_index(els, fn el, i -> element_to_question(el, i) end),
    complete_text: json["completeText"] || "Next"
  }
end
```

Each element's `"type"` and `"multiSelect"` values will appear in the log. Cross-reference with the `element_to_question` clauses to confirm the right clause is being matched.

---

## Layer 5: Did the Builder Overwrite the Config?

The `handle_info({:survey_builder_update, survey_json}, ...)` handler in `builder.ex` writes the survey component's output back to the selected trial's config. If the component mounted with empty questions (due to a parse failure), any subsequent user interaction triggers `notify_parent` with `%{}` (the result of `to_survey_json([])`), which then overwrites the in-memory config.

**This does NOT write to the database** — the builder only saves to DB when the user explicitly clicks Save. So:
- If the config is bad in the DB: the study was saved after the overwrite happened.
- If the config is good in the DB but bad in the editor session: the overwrite happened in memory only; refreshing the page will reload from DB.

**To confirm:** Refresh the builder page and immediately check if the config appears. If it reappears after refresh but disappears after clicking the block, the in-memory overwrite is occurring.

---

## Permanent Fix Checklist

When this symptom reoccurs, work through these checks in order:

- [ ] `priv/jspsych_registry.json` contains a `"survey"` entry with `survey_json` parameter of type `"OBJECT"`.
- [ ] `node assets/setup_jspsych.mjs` runs without removing the survey entry (check for `✓ survey (fallback)` in output).
- [ ] DB trial config has `survey_json` as a nested map with an `"elements"` array (not nil, not `%{}`).
- [ ] `parse_survey_json` receives the correct map (debug log in `update/2`).
- [ ] All question types in the stored elements have matching `element_to_question` clauses.

---

## Root Cause of This Specific Incident

The `"survey"` entry was present in `priv/jspsych_registry.json` until it was deleted during a `node assets/setup_jspsych.mjs` run triggered by an unrelated change (renaming the `multi-image-select` plugin). Because `@jspsych/plugin-survey` crashes on Node.js import, its entry was silently dropped every time the script ran.

**Resolution:** A `PLUGIN_FALLBACKS` map was added to `assets/setup_jspsych.mjs` that injects the known survey parameter schema whenever the live import fails. The entry is now stable across repeated script runs.
