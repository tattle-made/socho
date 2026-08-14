# QA Guide: Export Data

This guide verifies that submission data and study templates can be exported correctly, and that study templates can be reimported to create new studies.

---

## Prerequisites

- Logged in as **Admin** or **Manager**.
- A study exists with at least **two participant submissions** (run Guide 01 first, or use an existing study with data).
- The study has questions with distinct field names so data columns are identifiable.

For this guide, assume the study **QA Survey Test** from Guide 01 is used, with submissions from at least two participants.

---

## Part 1: Export Submissions as CSV

### Step 1.1 — Navigate to the Study

1. Go to **Studies** and open **QA Survey Test**.

### Step 1.2 — Trigger the CSV Export

1. Locate the **Export** button or link in the study view (typically in the study settings or toolbar).
2. Click **Export Submissions**.

**Expected:** A file download begins automatically.

### Step 1.3 — Check the Filename

**Expected filename:** `qa-survey-test-submissions.csv`
(Study title lowercased and hyphenated, with `-submissions.csv` suffix.)

### Step 1.4 — Open and Inspect the CSV

Open the downloaded CSV in a spreadsheet application or text editor.

**Expected structure:**

| submission_id | submitted_at | trial_1_respondent_name | trial_1_respondent_age | trial_1_education_level | trial_1_daily_devices | trial_1_satisfaction_rating | trial_1_country | trial_1_additional_feedback |
|---|---|---|---|---|---|---|---|---|
| (uuid) | (timestamp) | (text) | (number) | (choice) | (json array) | (number) | (text) | (text) |

Verify:
- [ ] First row is a header row with `submission_id`, `submitted_at`, and one column per question field name per trial.
- [ ] Column names follow the pattern `trial_N_fieldname`.
- [ ] Each subsequent row corresponds to one participant's submission.
- [ ] Text answers appear unquoted or correctly quoted (no broken columns).
- [ ] The checkbox question (`daily_devices`) — which allows multiple selections — is stored as a JSON array (e.g., `["Smartphone","Laptop"]`).
- [ ] Number fields (`respondent_age`, `satisfaction_rating`) are plain numbers.
- [ ] Timestamps in `submitted_at` are valid ISO 8601 or readable date-time strings.

### Step 1.5 — Verify Data Accuracy

Cross-reference at least two rows in the CSV against known submissions:

1. Pick participant A's submission. Confirm their name, age, education level, and country match what they entered.
2. Pick participant B's submission. Confirm independently.

**Expected:** All values match. No data is truncated, transposed, or missing.

### Step 1.6 — Edge Case: Empty Submission

If a participant skipped optional fields (e.g., `additional_feedback`), confirm:
- [ ] The column is present in the CSV but the cell is empty (not missing or erroring).

---

## Part 2: Export Study Template as JSON

The template export captures the study structure (blocks, question configs) without participant data. It is used to replicate studies.

### Step 2.1 — Trigger the Template Export

1. In the study view for **QA Survey Test**, locate **Export Template** (may be under a settings or actions menu).
2. Click **Export Template**.

**Expected:** A file download begins.

### Step 2.2 — Check the Filename

**Expected filename:** `qa-survey-test-template.json`

### Step 2.3 — Inspect the JSON

Open the downloaded JSON file and verify:

```json
{
  "socho_version": 1,
  "title": "QA Survey Test",
  "nodes": [...]
}
```

- [ ] `socho_version` is present (value `1`).
- [ ] `title` matches the study name.
- [ ] `nodes` is a non-empty array.
- [ ] Each node contains: `node_type`, `plugin`, `config` (with `survey_json` for survey trials), and optionally `children`.
- [ ] Survey questions inside `config.survey_json.elements` include the field names and types set in the builder.

---

## Part 3: Import a Study Template

### Step 3.1 — Navigate to Import

1. Go to **Studies**.
2. Locate the **Import Template** option (button or link on the studies list page).

### Step 3.2 — Upload the Exported File

1. Select the `qa-survey-test-template.json` file exported in Part 2.
2. Confirm the upload.

**Expected:** You are redirected to the edit page of a newly created study.

### Step 3.3 — Verify the Imported Study

1. Check the study title — it should match or derive from the template title.
2. Open the builder and verify:
   - [ ] The same blocks exist as in the original study.
   - [ ] Survey questions inside each block have the same titles, field names, and types as the original.
3. Confirm this is a **new study** (different ID) — the original study is unchanged.

### Step 3.4 — Invalid File Test

1. Attempt to import a plain text file or a JSON file that does not contain a `nodes` array.

**Expected:** An error message is displayed. No study is created. The user is not redirected to an edit page.

---

## Pass Criteria

- [ ] CSV export downloads with the correct filename.
- [ ] CSV contains correct headers and one row per submission.
- [ ] Multi-select answers are JSON-encoded in the CSV.
- [ ] Empty optional fields appear as empty cells, not errors.
- [ ] Template JSON downloads with `socho_version`, `title`, and `nodes`.
- [ ] Importing a valid template creates a new identical study.
- [ ] Importing an invalid file shows an error and creates no study.
