# QA Guide: Dynamic Multiselect Matrix

The dynamic multiselect matrix lets one survey question draw its column headers from a participant's answers to a previous matrix question. This guide sets up a two-trial study, collects data in the first trial, and verifies the second trial uses those answers as columns.

---

## Prerequisites

- Logged in as **Admin** or **Manager**.
- At least one client with at least one participant exists.
- You understand basic study and survey building (see Guide 01).

---

## Setup: Create the Study

1. Create a new study: **Dynamic Matrix QA**.
2. Add a **Survey** trial block. Rename it `Survey 1`.
3. Add a second **Survey** trial block. Rename it `Survey 2`.

---

## Part 1: Build Survey 1 — The Source Matrix

Survey 1 collects a static multiselect matrix whose **row values** will become the dynamic columns in Survey 2.

### Step 1.1 — Configure the Data Tag

1. Select `Survey 1`.
2. Find the **Data Tag** field in the trial configuration panel.
3. Set the data tag to: `survey_1_data`.

**Expected:** The data tag is saved and visible when you reselect the block.

### Step 1.2 — Add a Matrix Multiselect Question

1. Open the survey editor for `Survey 1`.
2. Add a question. Select type **Matrix Multiselect** (static).
3. Configure as follows:
   - **Title:** `Which activities did you do this week?`
   - **Field name:** `weekly_activities`
   - **Rows (activities):**
     - `Reading`
     - `Exercise`
     - `Cooking`
     - `Socialising`
   - **Columns (ratings/options):**
     - `Mon`
     - `Tue`
     - `Wed`
     - `Thu`
     - `Fri`
4. Mark as **Required**.

**Expected:** A 4-row × 5-column matrix preview appears.

### Step 1.3 — Add a Plain Question (Optional Filler)

1. Add a second question, type **Text**.
2. Title: `Any notes about your week?`, field name: `week_notes`.

---

## Part 2: Build Survey 2 — The Dynamic Matrix Consumer

Survey 2 presents a new matrix whose **columns are dynamically populated** from the row selections made in Survey 1.

### Step 2.1 — Add a Dynamic Matrix Question

1. Open the survey editor for `Survey 2`.
2. Add a question. Select type **Dynamic Matrix**.
3. Configure:
   - **Title:** `How would you rate each activity you did?`
   - **Field name:** `activity_ratings`

### Step 2.2 — Configure the Dynamic Source

4. In the dynamic matrix configuration, fill in:
   - **Source data tag:** `survey_1_data`
   - **Source question:** `weekly_activities`
   - **Filter by column value:** leave blank (no filter for this test)
5. In **Static Columns** (always-visible columns), add:
   - `Enjoyment`
   - `Effort`
6. Mark as **Required**.

**Expected:** Configuration saves without error. The preview may show placeholder columns at this point.

---

## Part 3: Test as a Participant

### Step 3.1 — Publish the Study

1. Publish the study **Dynamic Matrix QA**.

### Step 3.2 — Complete Survey 1

1. Log in (or switch to) a **Participant** account on the same client.
2. Launch **Dynamic Matrix QA** from the participant dashboard.
3. In Survey 1:
   - Select the following activities as done this week:
     - `Reading` on `Mon`, `Wed`
     - `Exercise` on `Tue`, `Thu`
     - `Cooking` on `Fri`
     - Leave `Socialising` with no selections.
   - Enter any text in the notes field.
4. Submit Survey 1.

**Expected:** Survey 1 submits and the study advances to Survey 2.

### Step 3.3 — Verify Dynamic Columns in Survey 2

5. Survey 2 now loads. **Inspect the dynamic matrix question.**

**Expected columns:** The columns should reflect the rows from Survey 1's matrix question, specifically:
- `Reading`
- `Exercise`
- `Cooking`
- `Socialising`
- Plus the two static columns: `Enjoyment` and `Effort`

> The key assertion: columns are derived from Survey 1's matrix row definitions, not hardcoded. All four row labels appear as column headers.

### Step 3.4 — Fill in Survey 2

6. For each row in the dynamic matrix, select values in the `Enjoyment` and `Effort` columns.
   - For example: Reading → Enjoyment: ✓, Effort: ✗
7. Submit Survey 2.

**Expected:** Submission completes without error.

---

## Part 4: Verify with a Second Participant (Edge Case)

Repeat Part 3 with a different participant who makes **different selections** in Survey 1:
- Select only `Exercise` and `Socialising`.
- Leave `Reading` and `Cooking` unselected.

**Expected in Survey 2:** The dynamic matrix still shows all four rows (Reading, Exercise, Cooking, Socialising) as column headers — the dynamic columns come from the **row definitions**, not from which rows were selected.

> This confirms the dynamic column logic reads row labels from the source question structure, not from filtered participant responses.

---

## Part 5: Test with Column Filter (Optional)

1. Edit **Survey 2**'s dynamic matrix question.
2. Set **Filter by column value:** `Mon`.
3. Repeat the participant flow from Part 3.

**Expected:** Only activities that had a selection in the `Mon` column in Survey 1 appear as dynamic columns in Survey 2.

Reset the filter to blank when done.

---

## Pass Criteria

- [ ] Survey 1 renders a static multiselect matrix with correct rows and columns.
- [ ] Survey 2's dynamic matrix shows column headers matching Survey 1's row labels.
- [ ] Static columns (`Enjoyment`, `Effort`) always appear alongside dynamic columns.
- [ ] Both participants see the same column structure (columns come from row definitions, not per-participant selections).
- [ ] Submission completes and data is recorded for both trials.
- [ ] Column filter (if tested) correctly limits the dynamic columns shown.
