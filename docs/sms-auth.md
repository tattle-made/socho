# Plan: SMS-based Authentication

## Overview

The existing magic link flow uses `UserToken` (stored hashes) + `UserNotifier` (email delivery). SMS auth plugs into the same token infrastructure but uses short OTP codes instead of URL tokens, delivered via a swappable SMS adapter.

---

## 1. SMS Adapter Behaviour (Vendor-Agnostic Layer)

Create `lib/socho/sms/` with:

- **`Socho.SMS.Adapter`** — a behaviour with a single callback:
  ```elixir
  @callback send_sms(to :: String.t(), body :: String.t()) :: :ok | {:error, term()}
  ```
- **`Socho.SMS.Adapters.Twilio`** — concrete implementation
- **`Socho.SMS.Adapters.Local`** — dev/test implementation that logs to console (mirrors Swoosh's local adapter)
- **`Socho.SMS`** — thin dispatcher that reads adapter from config and delegates

Config-driven selection keeps vendor swap to a one-line change in `config/`.

---

## 2. Schema Changes

**`users` table** — new migration adds:
- `phone_number` (string, nullable, unique) — E.164 format
- `verification_method` (enum: `:email` | `:sms`, default `:email`)

**`users_tokens` table** — no schema change needed. The existing `context` and `sent_to` fields already support this. Use `context: "sms_login"` and `sent_to: phone_number`.

---

## 3. OTP Token Support in `UserToken`

Add `build_sms_token/1`:
- Generates a 6-digit numeric OTP (instead of a 32-byte URL token)
- Stores SHA256 hash in DB with `context: "sms_login"`, expiry: 10 minutes
- Returns plain OTP for delivery

Add `verify_sms_token_query/2` (phone + code).

---

## 4. `UserSMSNotifier`

Mirrors `UserNotifier` but for SMS. Key functions:
- `deliver_login_otp/2` — sends "Your Socho code is 123456"
- `deliver_registration_otp/2` — same message, different context

---

## 5. `Accounts` Context Updates

- `register_user_with_sms/1` — creates user with `verification_method: :sms`
- `deliver_sms_login_instructions/2` — builds OTP token, calls `UserSMSNotifier`
- `verify_sms_otp/2` — validates OTP, returns user (mirrors `login_user_by_magic_link/1`)

The existing email path remains untouched.

---

## 6. Registration UI

In `UserLive.Registration`, add:
- Phone number field (shown/hidden based on choice)
- Toggle/radio: "Verify via Email" vs "Verify via SMS" (defaults to email)
- Client-side validation: phone format

---

## 7. Login & Confirmation UI

In `UserLive.Login`:
- After submit, branch on `user.verification_method`: show "check your email" or "enter the 6-digit code sent to your phone"

New `UserLive.SMSConfirmation` LiveView (or extend `UserLive.Confirmation`):
- Single input for the 6-digit code
- Submit calls `Accounts.verify_sms_otp/2` → `UserSessionController.create/2`
- Resend button (rate-limited)

---

## Key Tradeoffs / Open Questions

| Question | Recommendation |
|---|---|
| OTP length | 6 digits — industry standard |
| OTP expiry | 10 min (shorter than magic links since codes are guessable) |
| Rate limiting | Needed on OTP requests — `Hammer` or a simple DB counter |
| Phone number verification at registration | Send OTP immediately on register, confirm before account is usable |
| Can a user switch methods later? | Defer to a later feature; add `update_verification_method` changeset when ready |

---

## File Checklist

| New | Modified |
|---|---|
| `lib/socho/sms.ex` | `lib/socho/accounts/user.ex` |
| `lib/socho/sms/adapter.ex` | `lib/socho/accounts/user_token.ex` |
| `lib/socho/sms/adapters/twilio.ex` | `lib/socho/accounts.ex` |
| `lib/socho/sms/adapters/local.ex` | `lib/socho_web/live/user_live/registration.ex` |
| `lib/socho/accounts/user_sms_notifier.ex` | `lib/socho_web/live/user_live/login.ex` |
| `lib/socho_web/live/user_live/sms_confirmation.ex` | `priv/repo/migrations/` (2 fields) |
