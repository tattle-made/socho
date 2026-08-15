# QA Guide: Creating a Survey

This guide walks through creating a study with a survey trial and tests several question types. Complete it end-to-end and verify that each step produces the expected result.

---

## Prerequisites

- You are logged in as an **Admin** or **Manager**.
- At least one **Client** exists in the system.

---

## Steps

### 1. Create a New Study

1. Navigate to **Studies** in the top navigation.
2. Click **New Study**.
3. Enter a title: `QA Survey Test`.
4. Select any available client.
5. Click **Create Study**.

**Expected:** You are redirected to the study edit page. The study appears in the studies list.

---

### 2. Add a Survey Trial

1. In the study builder, click **Add Block**.
2. From the plugin list, select **Survey** (or the survey plugin).
3. Confirm the block appears in the builder panel.

**Expected:** A new trial block labelled "Survey" appears.

---

### 3. Open the Survey Editor

1. Click the survey block to select it.
2. In the configuration panel, locate the **Survey Builder** section.
3. Click **Add Question**.

---

### 4. Add Question: Short Text

1. From the question type dropdown, select **Text**.
2. Set the title to: `What is your name?`
3. Set field name to: `respondent_name`
4. Mark the question as **Required**.

**Expected:** A text input question appears in the preview.

---

### 5. Add Question: Number

1. Click **Add Question** again.
2. Select **Number**.
3. Set title: `How old are you?`
4. Set field name: `respondent_age`
5. Set minimum value: `1`, maximum value: `120`.
6. Mark as **Required**.

**Expected:** A number input appears in the preview with min/max constraints visible.

---

### 6. Add Question: Radio Group (Single Choice)

1. Add another question, select **Radio Group**.
2. Set title: `What is your highest level of education?`
3. Set field name: `education_level`
4. Add choices:
   - `High School`
   - `Bachelor's Degree`
   - `Master's Degree`
   - `Doctorate`
5. Mark as **Required**.

**Expected:** Four radio options display in the preview.

---

### 7. Add Question: Checkbox (Multiple Choice)

1. Add another question, select **Checkbox**.
2. Set title: `Which devices do you use daily?`
3. Set field name: `daily_devices`
4. Add choices:
   - `Smartphone`
   - `Laptop`
   - `Tablet`
   - `Smart TV`
5. Leave as **Not Required**.

**Expected:** Four checkbox options display. Multiple can be selected.

---

### 8. Add Question: Rating

1. Add another question, select **Rating**.
2. Set title: `How satisfied are you with this survey so far?`
3. Set field name: `satisfaction_rating`
4. Set rating range to **5**.

**Expected:** A row of five rating options (stars or numbers) displays.

---

### 9. Add Question: Dropdown

1. Add another question, select **Dropdown**.
2. Set title: `Which country do you live in?`
3. Set field name: `country`
4. Add choices:
   - `India`
   - `United States`
   - `United Kingdom`
   - `Germany`
   - `Australia`
5. Mark as **Required**.

**Expected:** A dropdown list with five options appears in the preview.

---

### 10. Add Question: Long Text (Comment)

1. Add another question, select **Comment**.
2. Set title: `Any additional feedback?`
3. Set field name: `additional_feedback`
4. Leave as **Not Required**.

**Expected:** A multi-line textarea appears in the preview.

---

### 11. Save and Publish

1. Click **Save** or navigate away to trigger autosave (observe the save indicator).
2. Return to the study list and confirm the study `QA Survey Test` appears.
3. Click **Publish** (if applicable) to make the study available to participants.

**Expected:** Study status changes to "Published".

---

### 12. Verify Participant View

1. Log out or open a private/incognito browser window.
2. Log in as a **Participant** assigned to the same client.
3. Navigate to the participant dashboard.
4. Locate and launch `QA Survey Test`.
5. Fill in answers for each question:
   - Enter name text.
   - Enter a valid age (e.g., `28`).
   - Select `Bachelor's Degree`.
   - Check `Smartphone` and `Laptop`.
   - Select rating `4`.
   - Select `India` from the dropdown.
   - Enter feedback text.
6. Click **Submit** (or the complete button).

**Expected:** Survey completes successfully. A submission record is created.

---

### 13. Verify Submission (Optional)

1. Log back in as Admin/Manager.
2. Navigate to the study and open **Submissions** or check **Export Data**.
3. Confirm the participant's answers appear correctly.

**Expected:** All seven field values are present and match what was submitted.

---

## Pass Criteria

- [ ] All seven question types render correctly in the participant view.
- [ ] Required fields block submission when left empty.
- [ ] Submitted data matches entered values.
- [ ] Study status changes to Published correctly.
