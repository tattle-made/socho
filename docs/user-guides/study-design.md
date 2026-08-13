# User Guide: Designing Studies in Socho

## Overview

A **study** in Socho is a sequence of blocks that a participant moves through one at a time. You arrange those blocks in the **Study Builder**, where you can add, rename, reorder, duplicate, and nest them without writing any code.

---

## Creating a New Study

From your dashboard, click **New Study**. This opens the Study Builder for a blank study.

The Study Builder has three main areas:

| Area | What it does |
|------|-------------|
| **Header bar** | Save your study, open a live Preview, and access study settings |
| **Left panel (Column 1)** | The block list — your study's structure |
| **Right panel (Column 2 + 3)** | Configuration for whichever block is selected |

Click **Save** in the header bar at any time to save your work. Click **Preview** to open the study in a new tab exactly as a participant would see it.

---

## What Are Blocks and Timeline Groups?

### Blocks

A **block** is a single screen shown to the participant. Each block runs one plugin — for example, a survey, an image display, a reaction-time task, or a video. When a participant reaches a block, the plugin runs to completion, then the study advances to the next block.

Every block has:
- A **name** (shown only to you in the builder)
- A **plugin type** (determines what the participant sees)
- **Configuration** (the settings for that plugin, edited in Column 2)

### Timeline Groups

A **timeline group** is a container that holds a sequence of blocks (and optionally other timeline groups). Use timeline groups to:

- **Repeat** a set of blocks multiple times (e.g., practice trials followed by test trials)
- **Group** related blocks so you can move or duplicate them together
- **Nest** complex trial structures (a timeline group can contain other timeline groups)

Timeline groups themselves are not shown to the participant — only the blocks inside them run.

---

## Adding Blocks

### Finding a Plugin

At the top of the left panel, there is a **search input** and a scrollable grid of plugin cards. Type any part of a plugin name to filter the list.

### Adding a Block to the Study

Click a plugin card to add a block of that type to the end of your study (or inside the currently selected timeline group, if one is selected). The new block appears in Column 1 and its configuration opens in Column 2.

### Adding a Timeline Group

Click the **+ Timeline Group** button at the top of the left panel. A new timeline group appears in your block list. If a timeline group is currently selected, the new group is added inside it — this lets you nest timeline groups as deeply as you need.

---

## Renaming Blocks and Timeline Groups

Every block row in Column 1 has an editable **name field** on the left side. Click into it and type to rename the block. The name is saved automatically as you type — no need to press Enter.

Descriptive names make large studies much easier to navigate. For example: `Consent Form`, `Practice Trials`, `Post-task Survey`.

---

## Reordering Blocks

### Drag and Drop

Each block row has a **⠿ drag handle** on its left edge. Click and hold the handle, then drag the block to a new position. You can:

- Reorder blocks within the same list
- Move a block into a timeline group by dragging it over the group's block list
- Move a block out of a timeline group back to the root level

The block list updates immediately when you release.

### Move Up / Move Down

Click the **⋯** menu button on the right side of any block row to open the action menu. Choose **Move up** or **Move down** to shift the block one position in its current list.

---

## Duplicating Blocks

Open the **⋯** menu on a block row and choose **Duplicate**. A copy of the block is inserted immediately after the original, with all the same configuration. Rename it to distinguish it from the original.

---

## Deleting Blocks

Open the **⋯** menu on a block row and choose **Delete**. The block is removed immediately. Deleting a timeline group removes it and all the blocks inside it.

---

## Selecting and Configuring a Block

Click anywhere on a block row (other than the name field) to select it. The block is highlighted and its configuration panel opens in Column 2. Changes in Column 2 apply to the selected block.

Click a different block to switch the configuration panel to that block.

---

## Tips

**Save often.** The builder does not auto-save. Use **Save** in the header bar regularly, especially before previewing or closing the tab.

**Name everything.** Default names like `Block 1` get confusing fast. Rename blocks and timeline groups as you add them.

**Use timeline groups for repeated sections.** If participants should see the same set of screens more than once (e.g., a fixation cross + stimulus + response on each trial), put those screens in a timeline group and configure repetitions in the timeline group's settings.

**Preview frequently.** The live Preview shows the study exactly as participants will see it. Open it after adding each new section to catch configuration problems early.

**Use the survey block for questionnaires.** If you need participants to answer questions, add a **survey** block. See the [Survey Design guide](survey-design.md) for a full walkthrough of all question types.
