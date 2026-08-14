# QA Guide: Builder UI

This guide tests the Study Builder interface. You will add trial blocks and timeline blocks, populate them with values, duplicate and reorder them, and verify the final state is accurate.

---

## Prerequisites

- Logged in as **Admin** or **Manager**.
- At least one client exists.
- You have an existing study to work in, or create one: **Builder UI Test**.

---

## Part 1: Add Trial Blocks

### Step 1.1 — Add Three Trial Blocks

1. Open (or create) the study **Builder UI Test**.
2. Click **Add Block**.
3. Select the **Survey** plugin. The block appears in the builder list.
4. Rename this block to `Block A` by editing its label in the configuration panel.
5. Click **Add Block** again.
6. Select the **Survey** plugin again.
7. Rename to `Block B`.
8. Click **Add Block** a third time.
9. Select the **Survey** plugin.
10. Rename to `Block C`.

**Expected:** Three blocks — Block A, Block B, Block C — appear in that order in the builder panel.

---

### Step 1.2 — Populate Block A

1. Select **Block A**.
2. In the configuration panel, add a survey question:
   - Type: **Text**, title: `Question in Block A`, field name: `block_a_q1`.
3. Note down: Block A has one text question.

---

### Step 1.3 — Populate Block B

1. Select **Block B**.
2. Add a survey question:
   - Type: **Rating**, title: `Rate your experience`, field name: `block_b_rating`.
3. Note down: Block B has one rating question.

---

### Step 1.4 — Populate Block C

1. Select **Block C**.
2. Add a survey question:
   - Type: **Checkbox**, title: `Select all that apply`, field name: `block_c_options`.
   - Add choices: `Option 1`, `Option 2`, `Option 3`.
3. Note down: Block C has one checkbox question with three options.

---

## Part 2: Add a Timeline Block

### Step 2.1 — Create a Timeline Block

1. Click **Add Timeline** (or Add Block → Timeline, depending on the UI).
2. A timeline block appears in the builder list. Rename it to `Timeline 1`.
3. Inside **Timeline 1**, click **Add Block**.
4. Add a **Survey** plugin block. Rename it `TL Block 1`.
5. Add another block inside **Timeline 1**. Rename it `TL Block 2`.

**Expected:** `Timeline 1` appears in the builder, with `TL Block 1` and `TL Block 2` nested under it (indented or visually grouped).

---

### Step 2.2 — Configure the Timeline

1. Select **Timeline 1**.
2. Set **Repetitions** to `3`.
3. Optionally enable **Randomize order**.

**Expected:** Timeline config saves without error. The repetitions value persists when you deselect and reselect Timeline 1.

---

### Step 2.3 — Populate TL Block 1

1. Select **TL Block 1** inside Timeline 1.
2. Add a question: Type **Boolean**, title: `Did you complete the task?`, field name: `tl_b1_complete`.

---

### Step 2.4 — Populate TL Block 2

1. Select **TL Block 2** inside Timeline 1.
2. Add a question: Type **Number**, title: `Time taken (seconds)`, field name: `tl_b2_time`, minimum: `0`.

---

## Part 3: Duplicate Blocks

### Step 3.1 — Duplicate Block B

1. Locate **Block B** in the builder list.
2. Click the **Duplicate** button (icon or menu option) on Block B.
3. A copy appears — rename it to `Block B Copy`.
4. Select **Block B Copy** and verify it has the same rating question (`Rate your experience`, field name `block_b_rating`).

**Expected:** The duplicate is an independent copy with identical configuration.

---

### Step 3.2 — Duplicate a Timeline Block

1. Locate **Timeline 1**.
2. Click **Duplicate** on Timeline 1.
3. Rename the copy to `Timeline 2`.
4. Expand Timeline 2 and verify it contains two blocks that mirror TL Block 1 and TL Block 2, including their question configurations.

**Expected:** Timeline 2 is a full deep copy: both child blocks and their survey questions are duplicated.

---

## Part 4: Move Blocks

### Step 4.1 — Move Block C Above Block A

1. Locate the top-level block order: `Block A`, `Block B`, `Block C`, `Block B Copy`, `Timeline 1`, `Timeline 2`.
2. Use the **Move Up** button on **Block C** (or drag it) until it is the first block in the list.

**Expected:** Block C is now at position 1. Block A is at position 2.

---

### Step 4.2 — Move Timeline 1 Below Timeline 2

1. Locate `Timeline 1` and `Timeline 2`.
2. Move **Timeline 1** down one position so it sits below `Timeline 2`.

**Expected:** The order is now `Timeline 2` then `Timeline 1`.

---

### Step 4.3 — Move a Block Inside a Timeline

1. Inside **Timeline 1**, move **TL Block 2** above **TL Block 1** using the Move Up action.

**Expected:** Inside Timeline 1, TL Block 2 now appears before TL Block 1.

---

## Part 5: Verify Final State

After all moves and duplications, the final expected block order is:

```
1. Block C         (checkbox question with 3 options)
2. Block A         (text question)
3. Block B         (rating question)
4. Block B Copy    (rating question — same as Block B)
5. Timeline 2      (deep copy of original Timeline 1)
   ├── TL Block 1  (boolean question)
   └── TL Block 2  (number question)
6. Timeline 1      (original, with reordered children)
   ├── TL Block 2  (number question) ← now first
   └── TL Block 1  (boolean question) ← now second
```

### Verification Checklist

Go through each block and confirm:

- [ ] **Block C** — position 1, has checkbox question with `Option 1`, `Option 2`, `Option 3`.
- [ ] **Block A** — position 2, has text question `block_a_q1`.
- [ ] **Block B** — position 3, has rating question `block_b_rating`.
- [ ] **Block B Copy** — position 4, has rating question `block_b_rating` (identical to Block B).
- [ ] **Timeline 2** — position 5, contains two child blocks with boolean and number questions.
- [ ] **Timeline 1** — position 6, repetitions still set to `3`, children now in reversed order (TL Block 2 first, TL Block 1 second).
- [ ] Selecting any block opens its config and shows previously entered values (no data loss after moves).

---

## Pass Criteria

- [ ] Blocks are added, named, and hold their configuration after reordering.
- [ ] Duplicate creates a full deep copy including nested question configs.
- [ ] Move Up/Down (and drag) correctly updates block order.
- [ ] Timeline child blocks can be reordered independently.
- [ ] No data loss occurs at any point during block manipulation.
