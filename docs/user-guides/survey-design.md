# User Guide: Designing Surveys in Socho

## Overview

The **survey** block lets you present one or more questions to a participant in a single screen. You can mix different question types in one block — free text, multiple choice, rating scales, rankings, and matrix grids — and control which questions are required.

This guide covers every question type available and the settings that apply to all questions.

---

## Adding a Survey Block

In the top plugin strip, click **survey**. A new block appears in **Column 1** and its configuration opens in **Column 2**. The right side of Column 2 shows a live preview that updates as you edit.

---

## The Survey Builder

Inside Column 2 you will see the **survey builder**, which has:

- A list of questions (empty at first)
- An **+ Add question** button at the bottom of the list
- A **Complete button text** field below that, which controls the label on the submission button (defaults to "Next")

Click **+ Add question** to add your first question. Each question card shows:

| Control | Purpose |
|---------|---------|
| **Type** buttons | Switch the question to a different type |
| **Question text** editor | The text shown to the participant (supports bold, italic, headings, links, images) |
| **Required** checkbox | If checked, the participant cannot submit without answering |
| **Field name** input | The key under which the answer is stored in your exported data |

---

## Question Types

### HTML content

Inserts a block of formatted text or HTML into the survey page — not a question, just content. Use it for instructions, images, or section headings between groups of questions.

The editor supports rich text (bold, italic, headings, bullet lists, links, images). No answer is collected.

---

### Short text

A single-line text input. Use it for names, short labels, or any free-form answer that fits on one line.

No extra settings beyond the common ones.

---

### Number

A number input. Two optional fields appear:

- **Min value** — the lowest number the participant is allowed to enter
- **Max value** — the highest number allowed

Leave either blank to impose no limit. If the participant enters a value outside the range, the survey will show a validation error and prevent submission.

---

### Long text

A multi-line text area. Use it for open-ended responses, feedback, or anything that needs more than a sentence.

---

### Single choice

A radio button group. The participant must pick exactly one option.

Click **+ Add choice** to add options. Each choice appears as a text input — type the label the participant will see. Click **✕** on a choice row to remove it.

The answer stored in your data is the text of the selected choice exactly as you typed it.

---

### Multiple choice

A checkbox group. The participant can select any number of options, including none (unless the question is marked Required, in which case at least one must be checked).

Add and remove choices the same way as Single choice. The answer is stored as a list of the selected choice labels.

---

### Dropdown

Presents the same set of choices as a collapsible dropdown menu instead of a visible list. Use this when you have many options and want to save vertical space.

Add choices the same way as Single choice.

---

### Rating scale

A horizontal star/number rating control. The participant clicks a value on the scale.

No choices to configure — the scale range is handled automatically by the survey engine.

---

### Yes / No

A single toggle with two states: Yes and No. Use it for consent questions, binary preferences, or simple confirmation steps.

No choices to configure.

---

### Ranking

A drag-to-reorder list. The participant is shown all the choices you define and drags them into their preferred order. The answer stored in your data is the full ordered list of choice labels, from most preferred to least.

Add choices the same way as Single choice. The order you add them is the starting order shown to the participant.

---

### Multi-Select Matrix

A grid of checkboxes. Rows are the items being rated and columns are the response options. The participant can check any combination of cells — multiple columns per row, or none.

**Common use:** Likert-style scales where participants rate several statements on the same set of response options (e.g., Strongly disagree → Strongly agree).

#### Adding rows and columns

Two sections appear below the question text:

- **Rows** — each row is a statement or item. Click **+ Add row** to add one.
- **Columns** — each column is a response option. Click **+ Add column** to add one.

#### Forward and reverse coding

Each row has a **Reverse** checkbox next to its label.

- **Forward coding (default, unchecked):** the leftmost column scores lowest and the rightmost scores highest. For a five-column scale, Strongly disagree = 1, Strongly agree = 5.
- **Reverse coding (checked):** the scoring is flipped. Strongly disagree = 5, Strongly agree = 1.

Use reverse coding for negatively-worded items in a scale. For example:

| Row | Reverse? |
|-----|----------|
| "Cat videos make me happy" | No (forward) |
| "Explosion videos make me sad" | No (forward) |
| "I feel anxious watching nature documentaries" | Yes (reverse) |

**Important:** The raw data exported from Socho stores which column the participant selected, not the numeric score. The reverse coding flag is recorded alongside the data so that your analysis pipeline can apply the correct scoring. A future version of Socho will apply the transformation automatically during export.

---

## Common Settings for All Questions

### Question text

The rich text editor supports:

- **B** / **I** — bold and italic
- **H1** / **H2** — section headings
- **• List** / **1. List** — bullet and numbered lists
- **🔗** — insert a hyperlink
- **🖼** — insert an image by URL

### Required

When checked, the survey will not allow submission until the participant has answered this question. An error message appears next to the unanswered question.

### Field name

This is the key used in your exported data file. It defaults to `question1`, `question2`, etc. **Change it to something meaningful** — for example `age`, `consent`, or `mood_scale` — so your data is easy to work with after export.

Field names must be unique within a survey block. Use only letters, numbers, and underscores (no spaces).

---

## Complete Button Text

At the bottom of the survey builder, the **Complete button text** field controls what the submission button says. The default is **Next**. Change it to **Submit**, **Done**, or any label appropriate to the context of your study.

---

## Tips

**Order questions deliberately.** Questions are presented to participants in the order they appear in the builder. Drag the question cards to reorder them (click and hold the left edge of a card).

**Use HTML content blocks for structure.** If your survey has multiple sections, insert an HTML content block before each group of questions with a heading explaining what that section is about.

**Name your survey block.** In Column 1, the survey block row has a text input where you can give the block a name (e.g., "Screening Survey" or "Post-task questionnaire"). This makes large studies much easier to navigate.

**Tag your block for conditional logic.** If other blocks in your study need to branch based on answers from this survey, scroll to the bottom of Column 2 and set a **Tag** on the block. See the [Conditional Survey guide](conditional-survey.md) for the full walkthrough.
