# Creating and Signing In as an Admin

## Overview

An **Admin** has full access to Socho and can manage studies, users, clients, and user roles.

This section explains how to create an Admin account and sign in to Socho.

---

## Creating an Admin Account

Before you can use Socho as an **Admin**, you must first create a regular user account.

> **Note:** By default, every new user is assigned the **Participant** role. Creating an account through the Sign Up page does **not** create an Admin account.

Follow the steps below to create a user account.

### Step 1

On the home page, click **Sign In**.

**Result:** The **Sign In** page opens.

![Log In page](assets/sing-in/log-in-page.png)

*Figure 1: The Socho Sign In page.*

---

### Step 2

On the **Sign In** page, click **Sign up** to create a new account.

**Result:** The **Registration** page opens.

![register-page](assets/admin-user/register-page.png)

*Figure 2: The Socho Registration page.*

---

### Step 3

Enter your email address and click **Create an account**.

**Result:** The **Sign In** page opens again.

![Log In page](assets/sing-in/log-in-page.png)

*Figure 3: The Socho Sign In page.*

---

### Step 4

Enter your email address and click **Log in with email**.

Find the blue notification box above the Email field, then click the **mailbox page** link.

![Mail box text link](assets/sing-in/mail-box-link.png)

**Figure 4:** Mailbox page link.

The Mailbox page opens.

Open the latest email.

![Mailbox page](assets/sing-in/mailbox-page.png)

**Figure 5:** The Socho Mailbox page.

---

### Step 5

click the confirmation link.

**Result:** The **Confirm my account** page opens.

![Confirm my account page](assets/sing-in/confirmation-page.png)

*Figure 5: The Socho Confirm my account page.*

---

### Step 6

Click **Confirm and stay logged in**.

**Result:** Your account is created successfully.

Since every new user is assigned the **Participant** role by default, you will be redirected to the **Studies** dashboard.

If no studies have been assigned to your account, the following message is displayed:

> **No published studies are available yet.**

![Participant Dashbord](assets/participant-user/no-assign-study.png)


*Figure 7: The Participant Studies dashboard.*

---

## Changing the Participant Role to Admin

The account you created is currently a **Participant** account. Participants cannot create or manage studies.

To get full access to Socho, you need to change the user's role from **Participant** to **Admin** using the Interactive Elixir (IEx) shell.

Follow the steps below to update the user's role.

### Step 1: Open the Socho Project

Open the Socho project in Visual Studio Code.

Open a new terminal and make sure you are inside the project directory.

### Step 2: Start the Phoenix Server

Run the following command:

```bash
iex -S mix phx.server
```

### Step 3: Load the Required Modules

```elixir
alias Socho.Repo
alias Socho.Accounts.User
```

### Step 4: Find the User

```elixir
user = Repo.get_by(User, email: "example@gmail.com")
```

Replace `example@gmail.com` with the email address you used to create your account.

### Step 5: Change the User Role to Admin

```elixir
user
|> Ecto.Changeset.change(role: :admin)
|> Repo.update()
```

**Result:** The user's role is updated successfully.

### Step 6: Verify the Updated Role

```elixir
Repo.get_by(User, email: "example@gmail.com")
```

Verify that the output contains:

```elixir
role: :admin
```

### Step 7: Sign In Again

After creating the Admin account, sign in using the same email address.

### Step 1

Open your browser and go to:

```text
http://localhost:4000
```

The Socho home page opens.

![Socho Home Page](assets/sing-in/home-page.png)

**Figure 8:** The Socho home page.

---

### Step 2

Click **Sign In**.

**Result:** The Sign In page opens.

![Log In page](assets/sing-in/log-in-page.png)

**Figure 9:** The Sign In page.

---

### Step 3

Enter the same email address and password that you used while creating the Admin account.

Click **Log in and stay logged in**.

Find the blue notification box above the Email field, then click the **mailbox page** link.

![Mail box text link](assets/sing-in/mail-box-link.png)

**Figure 10:** Mailbox page link.

---

### Step 4

The Mailbox page opens.

Open the latest email.

![Mailbox page](assets/sing-in/mailbox-page.png)

**Figure 11:** The Socho Mailbox page.

---

### Step 5

Click the confirmation link in the email.

The **Confirm my account** page opens.

![Confirm my account page](assets/sing-in/confirmation-page.png)

**Figure 12:** The Socho Confirm my account page.

---

### Step 6

Click **Confirm and stay logged in**.

**Result:**

Your Admin account has been created successfully, and you now have full access to Socho.

## What an Admin Can Do

An **Admin** has full access to all features in Socho. Admins can manage studies, users, clients, and system settings.

An Admin can:

- Create, edit, preview, publish, and delete studies.
- Build surveys using blocks and templates.
- View participant responses and export study data as CSV.
- Create, edit, and delete clients.
- Assign studies to clients.
- Invite participants to clients.
- View and manage all users.
- Invite new users.
- Import users using a CSV file.
- Edit user information, including display name, client, and role.
- Create Admin, Manager, and Participant accounts.
- Promote or change user roles.
- Access all studies and clients across the system.

---

# Creating and Signing In as a Manager

## Overview

A **Manager** can create and manage studies, manage clients, assign studies to clients, and invite participants. However, a Manager cannot create Admin or Manager accounts or change user roles to Admin or Manager.

This section explains how to create a Manager account and sign in to Socho.

---

## Creating a Manager Account

Only an **Admin** can create a Manager account.

### Step 1: Sign in as an Admin

Sign in using an Admin account.

After signing in successfully, the Socho home page opens.

---

### Step 2: Open the Users Page

Click the **Users** card on the home page or click **Users** from the navigation bar.

**Result:** The **Users** page opens and displays the list of all users.

![User Page](assets/manager-user-account/user-page.png)

**Figure 13:** The Users page.

---

### Step 3: Open the Invite User Form

On the **Users** page, click **+ Invite User** in the top-right corner.

**Result:** The **Invite a New User** form opens.

![New User Form](assets/manager-user-account/new-user-form.png)

**Figure 14:** The Invite a New User form.

---

### Step 4: Send an Invitation

1. Enter the manager's **Email address**.
2. (Optional) Enter a **Display name**.
3. Select **Manager** from the **Role** dropdown.
4. Click **Send Invitation**.

**Result:** A confirmation message appears at the top of the page stating:

> **Invitation sent to [email address]**

This confirms that the invitation has been sent successfully.

![Confirm invitation message](assets/manager-user-account/confirm-invitation-message.png)

**Figure 15:** Invitation sent confirmation.

---

### Step 5: View the Manager Account

On the **Users** page, locate the Manager account you just invited and click **View**.

**Result:** The selected user's details page opens.

![User Details page](assets/manager-user-account/user-details-page.png)

**Figure 16:** The selected user's details page opens.

From this page, you can edit the manager's information, such as the display name, role (if permitted), and assigned client.

> **Note:** At this stage, the Manager account has been invited but has not yet been confirmed.

Copy the Manager's email address, then sign out of the Admin account.

---

# Signing In as a Manager

After creating the Manager account, sign in using the same email address.

---

### Step 1

The Socho home page opens.

![Socho Home Page](assets/sing-in/home-page.png)

**Figure 17:** The Socho home page.

---

### Step 2

Click **Sign In**.

**Result:** The Sign In page opens.

![Log In page](assets/sing-in/log-in-page.png)

**Figure 18:** The Sign In page.

---

### Step 3

Enter the email address that was used when creating the Manager account.

Click **Log in and stay logged in**.

Find the blue notification box above the Email field, then click the **mailbox page** link.

![Mail box text link](assets/sing-in/mail-box-link.png)

**Figure 19:** Mailbox page link.

---

### Step 4

The Mailbox page opens.

Open the latest email.

![Mailbox page](assets/sing-in/mailbox-page.png)

**Figure 20:** The Socho Mailbox page.

---

### Step 5

Click the confirmation link in the email.

The **Confirm my account** page opens.

![Confirm my account page](assets/sing-in/confirmation-page.png)

**Figure 21:** The Socho Confirm my account page.

---

### Step 6

Click **Confirm and stay logged in**.

**Result:**

Your Manager account has been created successfully. You can now sign in and manage studies assigned to you.

## What a Manager Can Do

A **Manager** can manage studies and clients but has limited administrative permissions.

A Manager can:

- Create, edit, preview, publish, and delete studies.
- Build surveys using blocks and templates.
- View participant responses and export study data as CSV.
- Create and manage clients.
- Assign studies to clients.
- Invite participants to clients.
- Create Participant accounts.
- View and manage studies that they have permission to access.

A Manager cannot:

- Create Admin accounts.
- Create Manager accounts.
- Change a user's role to Admin or Manager.
- Perform actions that require Admin privileges.

For detailed information about Admin and Manager features and workflows, see the User Roles Guide:

https://docs.google.com/document/d/1qVmNxrjSerOroCY-C5yvZvooohr8enEKAekTpVUsJnc/edit?tab=t.0#heading=h.gg6do12z4hiz

---

# Creating and Signing In as a Participant

## Overview

A **Participant** can access and complete studies that have been assigned to them. Participants cannot create or manage studies, users, clients, or user roles.

This section explains how to create a Participant account and sign in to Socho.

---

## Creating a Participant Account

Only an **Admin** or **Manager** can create a Participant account.

### Step 1: Sign in as an Admin or Manager

Sign in using an Admin or Manager account.

After signing in successfully, the Studies page opens.

---

### Step 2: Open the Users Page

Click the **Users** card on the home page or click **Users** from the navigation bar.

**Result:** The **Users** page opens and displays the list of all users.

![User Page](assets/manager-user-account/user-page.png)

**Figure 22:** The Users page.

---

### Step 3: Open the Invite User Form

On the **Users** page, click **+ Invite User** in the top-right corner.

**Result:** The **Invite a New User** form opens.

![New User Form](assets/manager-user-account/new-user-form.png)

**Figure 23:** The Invite a New User form.

---

### Step 4: Send an Invitation

1. Enter the participant's **Email address**.
2. (Optional) Enter a **Display name**.
3. Select **Participant** from the **Role** dropdown.
4. Click **Send Invitation**.

**Result:** A confirmation message appears at the top of the page stating:

> **Invitation sent to [email address]**

This confirms that the invitation has been sent successfully.

![Confirm invitation message](assets/manager-user-account/confirm-invitation-message.png)

**Figure 24:** Invitation sent confirmation.

---

### Step 5: View the Participant Account

On the **Users** page, locate the Participant account you just invited and click **View**.

**Result:** The selected user's details page opens.

![User Details page](assets/participant-user/participant-detail-page.png)

**Figure 25:** The selected user's details page opens.

From this page, you can edit the participant's information, such as the display name and assigned client.

> **Note:** At this stage, the Participant account has been invited but has not yet been confirmed.

Copy the Participant's email address, then sign out of the current account.

---

# Signing In as a Participant

After creating the Participant account, sign in using the same email address.

---

### Step 1

The Socho home page opens.

![Socho Home Page](assets/sing-in/home-page.png)

**Figure 26:** The Socho home page.

---

### Step 2

Click **Sign In**.

**Result:** The Sign In page opens.

![Log In page](assets/sing-in/log-in-page.png)

**Figure 27:** The Sign In page.

---

### Step 3

Enter the email address that was used when creating the Participant account.

Click **Log in and stay logged in**.

Find the blue notification box above the Email field, then click the **mailbox page** link.

![Mail box text link](assets/sing-in/mail-box-link.png)

**Figure 28:** Mailbox page link.

---

### Step 4

The Mailbox page opens.

Open the latest email.

![Mailbox page](assets/sing-in/mailbox-page.png)

**Figure 29:** The Socho Mailbox page.

---

### Step 5

Click the confirmation link in the email.

The **Confirm my account** page opens.

![Confirm my account page](assets/sing-in/confirmation-page.png)

**Figure 30:** The Socho Confirm my account page.

---

### Step 6

Click **Confirm and stay logged in**.

**Result:**

Your Participant account has been created successfully. You can now sign in and participate in studies that have been assigned to you.

![Participant Dashbord](assets/participant-user/participant-dashbord.png)

**Figure 31:** The Participant dashboard or Studies page (if applicable).

## What a Participant Can Do

A **Participant** can view and complete studies that have been assigned to them. Participants have limited access and cannot manage studies, users, clients, or system settings.

A Participant can:

- View all studies assigned to them from the **Studies** dashboard.
- Open any assigned study.
- Complete and submit assigned studies.
- View only the studies assigned to their account.

A Participant cannot:

- Create, edit, publish, or delete studies.
- Create or manage users.
- Create or manage clients.
- Change user roles.
- Access administrative features.

---

## Completing an Assigned Study

### Step 1: Open the Studies Dashboard

Sign in using your Participant account.

**Result:** The **Studies** dashboard opens and displays all studies assigned to you.

![Participant Studies Dashboard](assets/participant/studies-dashboard.png)

**Figure 32:** The Participant Studies dashboard showing assigned studies.

---

### Step 2: Open an Assigned Study

Click the study you want to complete.

**Result:** The selected study opens.

![Assigned Study](assets/participant/assigned-study.png)

**Figure 33:** The selected study.

---

### Step 3: Complete the Study

Read each question and enter your responses.

Click **Continue** (or the appropriate navigation button) until you reach the last page of the study.

---

### Step 4: Submit the Study

After answering all required questions, click **Submit** (or the final **Continue** button).

**Result:** Your responses are submitted successfully. Blank page displayed after the study is submitted.


---

### Step 5: Open a Completed Study

If you open a study that you have already completed, After completing and submitting the study.

**Result:** The following message is displayed:

> **You have already completed this study. Thank you!**
