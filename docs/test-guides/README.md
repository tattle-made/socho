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

## Creating Test Users (iex)

Several guides require Admin, Manager, or Participant accounts to already exist. The quickest way to bootstrap them is via the `UserAdmin` helper in an iex shell.

**Start the shell:**

```bash
iex -S mix
```

**Create users:**

```elixir
alias Socho.Accounts.UserAdmin

# Admin — can manage everything
UserAdmin.create_user("admin@example.com", "AdminTestPass123", :admin)

# Manager — can create participants and manage studies
UserAdmin.create_user("manager@example.com", "ManagerTestPass123", :manager)

# Participant — scoped to a client; assign client_id separately via the UI
# or create one per client needed
UserAdmin.create_user("participant_a@example.com", "ParticipantPass123", :participant)
UserAdmin.create_user("participant_b@example.com", "ParticipantPass456", :participant)
```

Each call returns `{:ok, %User{}}` on success or `{:error, changeset}` on failure (e.g., duplicate email or password too short — minimum 12 characters).

After creating participant accounts, log in as Admin and go to **Users** to assign each participant to the correct **Client** before running guides that test client scoping.

---

## Running Order

Run the guides in order — later guides depend on data created by earlier ones:

1. **Guide 01** creates the baseline study and submissions used by Guide 04.
2. **Guide 02** is independent and can run any time.
3. **Guide 03** requires a two-trial study with a tagged source survey.
4. **Guide 04** requires at least two participant submissions (from Guide 01).
5. **Guide 05** is independent but requires two clients to exist.

## Pass / Fail Recording

Each guide ends with a **Pass Criteria** checklist. Mark each item as pass or fail and note the date, tester name, and environment (e.g., local dev, staging) at the top of the guide when running it.
