# Tracketiv

Daily, weekly, and group habit tracker with predefined goals, daily logs, comments, reactions, and reminders.

## Stack

- **Mobile:** Flutter
- **Backend:** Supabase (Postgres, Auth, Storage)

## Setup

### 1. Supabase project

1. Create a project at [supabase.com](https://supabase.com)
2. Run SQL migrations in order from [`supabase/migrations/`](supabase/migrations/):
   - `001_profiles.sql`
   - `002_goals.sql`
   - `003_social.sql`
   - `004_reminders.sql`
   - `005_seed_templates.sql`
   - `006_storage_and_profile_search.sql`
   - `007_groups_invites.sql`
   - `008_usernames.sql`
   - `009_profile_fields.sql`
3. In **Authentication → URL Configuration**, add redirect URL:
   - `io.supabase.tracketiv://reset-password`
4. Enable Email auth provider

### 2. Flutter app

```bash
cp .env.example .env
# Edit .env with your SUPABASE_URL and SUPABASE_ANON_KEY
flutter pub get
flutter run
```

**Web (Chrome) — use a fixed port so Supabase auth works:**

```bash
flutter run -d chrome --web-port=8080
```

Then in Supabase **Authentication → URL Configuration** set:

| Field | Value |
|-------|--------|
| **Site URL** | `http://localhost:8080` |
| **Redirect URLs** | `http://localhost:8080/**` |

Also add (for mobile password reset):

```
io.supabase.tracketiv://reset-password
```

### 3. Deep links (password reset)

Deep links for `io.supabase.tracketiv://reset-password` are configured in:

- **Android:** `android/app/src/main/AndroidManifest.xml`
- **iOS:** `ios/Runner/Info.plist`

## Features

- Register / login / forgot password / reset password
- Browse predefined goals (weight loss, steps, water, meditation, etc.)
- Join goals solo or as a group
- Daily logs with numeric values and optional notes
- Comments and reactions on logs
- Progress charts, streaks, and group motivation
- Local notification reminders per goal
- Profile with display name and avatar

## Project structure

```
lib/
  core/           # theme, router, config
  features/
    auth/         # login, register, forgot, reset
    goals/        # catalog, join, my goals, detail
    logs/         # add log
    social/       # comments, reactions
    reminders/    # local notifications
    profile/      # profile edit, avatar
  shared/         # models, widgets, utils
supabase/migrations/  # SQL schema and seeds
```
