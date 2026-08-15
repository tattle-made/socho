# QA Guide: User Creation and Access Control

This guide verifies that users can be created with the correct roles, that role-based permissions are enforced, and that participants are correctly scoped to their client.

---

## Prerequisites

- At least one **Admin** account exists and you can log in as Admin.
- At least two **Clients** exist: `Client Alpha` and `Client Beta`.
- At least one published study exists for each client.

---

## Part 1: Create a Manager via Invitation

### Step 1.1 — Open User Management

1. Log in as **Admin**.
2. Navigate to **Users** in the admin navigation.
3. Click **Invite User** (or **New User**).

### Step 1.2 — Invite a Manager

1. Enter email: `manager_qa@example.com`
2. Set role: **Manager**
3. Assign to: `Client Alpha`
4. Click **Send Invitation** (magic link flow).

**Expected:** A confirmation message appears. An invitation email is sent to the address.

### Step 1.3 — Verify in User List

1. Check the user list.
2. Confirm `manager_qa@example.com` appears with role `Manager` and client `Client Alpha`.
3. The account status should indicate unconfirmed (not yet logged in).

---

## Part 2: Create a Participant via Direct Password

### Step 2.1 — Create Participant for Client Alpha

1. Still as Admin, click **Invite User** again.
2. Enter email: `participant_alpha@example.com`
3. Set role: **Participant**
4. Assign to: `Client Alpha`
5. Choose **Set Password Directly** (admin override).
6. Enter password: `SecureTestPass123`
7. Click **Create**.

**Expected:** User is created immediately without sending an email. Appears in user list with role `Participant` and client `Client Alpha`.

### Step 2.2 — Create Participant for Client Beta

1. Repeat the process:
   - Email: `participant_beta@example.com`
   - Role: **Participant**
   - Client: `Client Beta`
   - Password: `SecureTestPass456`

**Expected:** Second participant created, assigned to `Client Beta`.

---

## Part 3: Verify Manager Permissions

### Step 3.1 — Log in as Manager

1. Log out of the Admin account.
2. Accept the invitation for `manager_qa@example.com` (click the magic link from the email, or confirm token directly).
3. Log in.

### Step 3.2 — Confirm Manager Can Create Participants

1. Navigate to **Users**.
2. Click **Invite User**.
3. Confirm the available roles are limited to **Participant** only (Manager cannot create other Managers or Admins).

**Expected:** The role dropdown shows only `Participant`. There is no option to assign `Manager` or `Admin`.

### Step 3.3 — Confirm Manager Cannot Access Admin-Only Settings

1. Attempt to navigate to **Settings > Branding** or any admin-only route.

**Expected:** Access is denied (redirect or error message). The manager cannot access admin-level configuration.

### Step 3.4 — Confirm Manager Can Access Studies

1. Navigate to **Studies**.
2. Verify that studies for the assigned client are visible and accessible.

**Expected:** Studies are visible. The manager can open, edit, and configure them.

---

## Part 4: Verify Participant Access Control

### Step 4.1 — Log in as Client Alpha Participant

1. Log out of the Manager account.
2. Log in as `participant_alpha@example.com` / `SecureTestPass123`.

**Expected:** You are redirected to the **Participant Dashboard**.

### Step 4.2 — Verify Only Client Alpha Studies Appear

1. On the dashboard, check the list of available studies.

**Expected:** Only studies belonging to `Client Alpha` appear. No studies from `Client Beta` are listed.

### Step 4.3 — Attempt Direct URL Access to Another Client's Study

1. Note the ID of a study belonging to `Client Beta` (from admin view).
2. As the Client Alpha participant, navigate directly to: `/studies/{client_beta_study_id}`

**Expected:** Access is denied. The participant sees a "Forbidden" message or is redirected. They cannot view or participate in Client Beta's study.

### Step 4.4 — Log in as Client Beta Participant

1. Log out.
2. Log in as `participant_beta@example.com` / `SecureTestPass456`.
3. Confirm only `Client Beta` studies appear on the dashboard.

**Expected:** Participant Beta can see Client Beta studies. Client Alpha studies are not shown.

---

## Part 5: Password Validation

### Step 5.1 — Test Short Password

1. As Admin, attempt to create a user with direct password set to: `short` (fewer than 12 characters).

**Expected:** Validation error: password must be at least 12 characters. User is not created.

### Step 5.2 — Test Valid Password Boundary

1. Create a user with a password of exactly 12 characters: `ExactlyTwelv`

**Expected:** User is created successfully.

---

## Part 6: Role Hierarchy Enforcement

### Step 6.1 — Manager Cannot Promote to Manager

1. Log in as Manager (`manager_qa@example.com`).
2. Open an existing participant user.
3. Attempt to change their role to `Manager`.

**Expected:** The option is not available. The role dropdown for a Manager creating/editing users only shows `Participant`.

### Step 6.2 — Participant Cannot Access User Management

1. Log in as `participant_alpha@example.com`.
2. Attempt to navigate to `/users`.

**Expected:** Access is denied. Participants cannot see or manage other users.

### Step 6.3 — Participant Cannot Access Study Builder

1. As `participant_alpha@example.com`, attempt to navigate to `/studies/{any_study_id}/edit`.

**Expected:** Access is denied. Participants can take surveys but cannot edit study configurations.

---

## Pass Criteria

- [ ] Admin can create Managers and Participants.
- [ ] Manager can create only Participants (not Managers or Admins).
- [ ] Participants can only access studies belonging to their assigned client.
- [ ] Direct URL access to another client's study is blocked for participants.
- [ ] Passwords shorter than 12 characters are rejected.
- [ ] Participants cannot access user management or the study builder.
- [ ] Manager cannot access admin-only settings pages.
