# Home Checklist

Daily checklists for the household team, with admin review. A Flutter web app
on Cloudflare (https://homechecklist.nahyan.workers.dev) with a Supabase
backend.

## What it does

For the maids
- Today's tasks from her own schedule, in time order.
- Every task needs a photo as proof; each medicine dose needs its own photo.
  A task without a photo counts as not done.
- Vital checks: BP, blood sugar and oxygen for Mama and Papa.
- Log breaks and free time (12-hour duty, 2-hour break).
- Night emergency: the other maid covers the morning so she can rest.
- Emergency screen with contact numbers and what to do.
- Works offline: everything is saved on the phone and sent when the internet is back.
- Push reminders when a task is due and when it is missed (Android, and iPhone
  once the app is added to the Home Screen).

For admins
- Each maid's progress, score and review status; confirm a day or send it back.
- Alerts for medicines not recorded or given twice.
- Weightage per task: a missed task is deducted from the day's score.
  Repeated misses move a maid through Warning, Final warning and Action.
- Edit schedules with changes that start on a chosen day; earlier days keep
  the old version.
- Approve people who sign up (as maid or admin), or add them directly.

## Accounts

The first account ever made becomes admin. After that, people tap "Create
account" and wait until an admin approves them; accounts an admin adds under
Team are approved at once. Forgot password sends a reset email.

## Code

| Path | What it holds |
| --- | --- |
| `lib/app_state.dart` | All data and rules, synced with Supabase, with unsent changes laid on top |
| `lib/outbox.dart` | Changes and photos kept on the phone until they are sent |
| `lib/templates.dart` | Mary's and Nisha's schedules to start a new maid with |
| `lib/screens/` | Login, maid and admin screens, task sheet, schedules, team, emergency |
| `lib/push/` | Web push sign-up |
| `supabase/migrations/` | Tables, access rules, photo storage, reminder timer |
| `supabase/functions/` | `manage-user` (accounts) and `send-reminders` (push, every 5 minutes) |
| `web/reminders_sw.js` | Shows push reminders on the phone |

## Run and deploy

```bash
flutter pub get
flutter run -d chrome
```

```bash
flutter build web --release
npx wrangler deploy
```

Database and functions, with the Supabase CLI logged in and linked to the project:

```bash
supabase db push --linked
supabase functions deploy manage-user
supabase functions deploy send-reminders --no-verify-jwt
```

The `send-reminders` function needs the secrets `VAPID_PUBLIC_KEY`,
`VAPID_PRIVATE_KEY` and `VAPID_SUBJECT`. The public key is also in
`lib/config.dart`; the private key is kept only in Supabase.
