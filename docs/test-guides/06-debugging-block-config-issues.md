# Debugging Guide: Block Configuration Issues in the Builder

This guide covers how to diagnose cases where a trial block behaves unexpectedly in the study builder — empty config panel, settings not saving, or a mismatch between what the editor shows and what participants see.

---

## How Block Config Flows Through the System

Two completely separate paths read from the database:

```
Preview path:  DB trial.config → js_generator.ex → embedded JS → participant browser
Editor path:   DB trial.config → builder assigns → param_field components → UI
```

A bug in one path does not affect the other. This is why a block can work correctly in preview while its config appears empty in the editor, or vice versa.

---

## Symptom: Config Panel is Empty or Shows "No Configurable Parameters"

### Check 1 — Is the plugin in the registry?

The builder only renders fields for parameters listed in the plugin registry. If a plugin's entry is missing from `priv/jspsych_registry.json` (for built-in plugins) or `priv/custom_plugins_registry.json` (for custom plugins), the config panel will be empty regardless of what is stored in the database.


```bash
# Check built-in plugins
node -e "const fs=require('fs'); const d=JSON.parse(fs.readFileSync('priv/jspsych_registry.json')); console.log(d['plugin-name'] ? 'PRESENT' : 'MISSING')"

# Check custom plugins
node -e "const fs=require('fs'); const d=JSON.parse(fs.readFileSync('priv/custom_plugins_registry.json')); console.log(d['plugin-name'] ? 'PRESENT' : 'MISSING')"
```

If an entry is missing, re-run the setup script which regenerates both registries:
```bash
node assets/setup_jspsych.mjs
```

### Check 2 — Is the data actually in the database?

Open an iex shell and query the trial directly:

```elixir
alias Socho.Repo
alias Socho.Studies.Trial

# Replace with the actual study ID (from the URL: /studies/:id/edit)
study_id = 123

Trial
|> Ecto.Query.where([t], t.study_id == ^study_id and t.plugin == "plugin-name")
|> Repo.all()
|> Enum.map(fn t -> {t.id, t.config} end)
```

**Expected:** each trial returns a config map with the parameters you set.

**Bad signs:**
- `config` is `%{}` → the config was never saved, or was overwritten with an empty map.
- A specific parameter key is missing → it was never written or was dropped somewhere in the save path.

### Check 3 — Does the builder's in-memory state match the database?

The builder holds trial configs in LiveView assigns, not directly from the database. These can diverge if a bug writes back to the assigns during a session. To rule this out, **refresh the page** and click the block immediately before doing anything else. If the config appears after a fresh load but is gone mid-session, the in-memory state is being overwritten (see "Settings Disappear After Interaction" below).

---

## Symptom: Settings Disappear After Interacting with the Block

This is an in-memory overwrite. The general sequence:

1. The block mounts and its config component fails to parse the stored value (returns an empty/default state).
2. Any user interaction (clicking a field, toggling a checkbox) triggers a change event.
3. The change event sends the current (empty) state back to the builder.
4. The builder writes the empty state into the trial's in-memory config.
5. The config now appears empty for the rest of the session.

**This does not write to the database** until the user explicitly saves. Refreshing the page reloads from DB and restores the config if the underlying data is intact.

To find the parse failure, add a temporary log at the point the component receives its value and trace what it does with it.

---

## Symptom: Block Works in Preview but Config is Empty in Editor

The preview path (`js_generator.ex`) reads `trial.config` directly from the database and embeds it in generated JavaScript. The editor path reads the same data but passes it through LiveView assigns and component rendering.

Checklist:
- [ ] Plugin is present in the registry (Check 1 above).
- [ ] DB config is correct (Check 2 above).
- [ ] The parameter name used as the config map key matches the parameter name in the registry exactly (case-sensitive).
- [ ] The `input_kind` mapping in `builder_components.ex` handles the parameter's type — unrecognised types fall through to `:text`, which may render incorrectly for complex values.

---

## Symptom: Block Config is Correct in Editor but Broken in Preview

The editor is reading and displaying config correctly, but the generated JavaScript is wrong.

1. Open the preview page and view the page source. Find the inline `<script>` block and search for the trial's variable (e.g. `trial3`, `timeline2`). Inspect the generated config object.
2. Check `js_generator.ex` — find the `config_to_js` or `emit_node` clause that handles this plugin. Add a temporary `IO.inspect` to see what it receives and what it emits.
3. Check the browser console for runtime errors from the plugin.

---

## Symptom: Config Saves Correctly but Resets on Page Reload

The in-memory config was correct but the save path didn't write it to the database, or wrote a different value.

1. Check the save handler in `builder.ex` — confirm it persists all trial configs, not just the selected one.
2. After saving, run the iex query from Check 2 and compare the DB values to what was shown in the editor.
3. Check for any transformation applied to config values before they are written (type coercion, key renaming, dropped fields).

---

## General Debugging Checklist

- [ ] Plugin entry exists in the appropriate registry file with the correct parameter names and types.
- [ ] `DB trial.config` contains the expected keys and values (iex query).
- [ ] Builder in-memory state matches DB (check immediately after page refresh, before any interaction).
- [ ] Parameter names in the registry match the keys used in `trial.config` exactly.
- [ ] `input_kind` in `builder_components.ex` maps the parameter type to the correct UI component.
- [ ] Generated JavaScript in preview page source matches the stored config.
- [ ] Browser console shows no plugin runtime errors during preview.
