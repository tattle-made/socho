# Manual QA Testing Guides

Step-by-step testing scripts for the Socho survey platform. Each guide covers one feature area and is written for a human tester working through the UI.

## Guides

| # | Guide | What it covers |
|---|-------|---------------|
| 01 | [Creating a Survey](01-creating-a-survey.md) | Add a study, build a survey with 7 question types, submit as participant, verify data |
| 02 | [Builder UI](02-builder-ui.md) | Add blocks and timeline blocks, populate with values, duplicate, reorder, verify final state |
| 03 | [Dynamic Multiselect Matrix](03-dynamic-multiselect-matrix.md) | Set up a two-trial study; verify dynamic columns are drawn from the previous survey's matrix rows |
| 04 | [Export Data](04-export-data.md) | Export submissions CSV and study template JSON; verify structure and accuracy; test template import |
| 05 | [User Creation & Access Control](05-user-creation-and-access-control.md) | Create Admin/Manager/Participant users, verify role-based permissions and client scoping |

## Running Order

Run the guides in order — later guides depend on data created by earlier ones:

1. **Guide 01** creates the baseline study and submissions used by Guide 04.
2. **Guide 02** is independent and can run any time.
3. **Guide 03** requires a two-trial study with a tagged source survey.
4. **Guide 04** requires at least two participant submissions (from Guide 01).
5. **Guide 05** is independent but requires two clients to exist.

## Pass / Fail Recording

Each guide ends with a **Pass Criteria** checklist. Mark each item as pass or fail and note the date, tester name, and environment (e.g., local dev, staging) at the top of the guide when running it.
