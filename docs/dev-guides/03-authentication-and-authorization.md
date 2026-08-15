# Authentication & Authorization

## Authentication Flow

```mermaid
sequenceDiagram
    participant U as User browser
    participant Auth as UserSessionController
    participant DB as PostgreSQL

    U->>Auth: POST /users/log_in (email + password)
    Auth->>DB: Accounts.get_user_by_email_and_password()
    DB->>Auth: User record
    Auth->>Auth: Bcrypt.verify_pass()
    Auth->>DB: Accounts.generate_user_session_token()
    DB->>Auth: session token
    Auth->>U: Set encrypted cookie + redirect

    Note over U,Auth: Subsequent requests
    U->>Auth: Request with cookie
    Auth->>DB: Accounts.get_user_by_session_token()
    DB->>Auth: User
    Auth->>Auth: Build Scope struct
    Auth->>U: Request proceeds
```

## Role-Based Access

There are three roles. Every request passes through a `Scope` struct that carries the current user and their client context.

```mermaid
flowchart TD
    Request --> FetchScope[fetch_current_scope_for_user plug]
    FetchScope --> Role{User role?}
    Role -->|admin| AdminRoutes[All studies, all users,\nall clients, app settings]
    Role -->|manager| ManagerRoutes[Studies for their client,\nparticipants for their client]
    Role -->|participant| ParticipantRoutes[Dashboard:\npublished studies for their client]
    Role -->|unauthenticated| PublicRoutes[Login, register,\nmagic link]
```

## Study Access Guard

When a participant loads a study, `StudyController` verifies their client matches the study's client before serving the page:

```mermaid
flowchart LR
    P[Participant\nclient_id = X] --> Check{study.client_id\n== X?}
    Check -->|yes| Serve[Serve study page]
    Check -->|no| Forbidden[403 Forbidden]
```

---
