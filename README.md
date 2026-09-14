# MeSee platform foundation

MeSee is being migrated from the static prototype to a Flutter + Supabase mobile application.

## Planned modules

- Auth and account switching
- Vertical and horizontal video feeds
- Camera, media upload, editing metadata, audio catalog
- Posts, likes, saves, reposts, follows, notifications and messages
- Creator analytics and revenue ledger
- Moderation, reports, blocks and admin-only controls
- LIVE setup, WebRTC stream metadata and real-time chat

## Required environment

- Flutter SDK
- Supabase project URL and anon key
- Video provider credentials (Mux or Cloudflare Stream)
- Firebase configuration for push notifications
- Stripe Connect configuration for creator payouts

The current browser prototype remains in `../mesee-prototype` while the native app is built.

Flutter configuration is passed without committing secrets:

```powershell
flutter run --dart-define=APP_ENV=development --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

## Local verification

From the `mesee-platform` directory:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\smoke-test.ps1
```

To preview the browser prototype, open `../mesee-prototype/index.html` in a browser. Camera and microphone features require `localhost` or HTTPS and an explicit browser permission grant.

For a permission-capable local preview:

```powershell
node .\tools\serve-prototype.js
```

Then open `http://127.0.0.1:8765`.

## Public-release checklist

Run the preflight before distributing a build:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\public-release-check.ps1
```

The check intentionally reports pending items until the production values are supplied:

1. Apply Supabase migrations `001`–`013` to the production project.
2. Configure `SUPABASE_URL` and `SUPABASE_ANON_KEY` as protected CI secrets. The release workflow reads these secrets and passes them as Dart defines; do not put them in source files.
3. Create a private Android upload keystore and copy `android/key.properties.example` to `android/key.properties` locally or provide the equivalent protected CI secrets. Never commit the key, passwords, or `key.properties`.
4. The store application ID is `com.mesee.app` for both Android and iOS; reserve it in the store consoles before submission.
5. Build the Android App Bundle in CI with `.github/workflows/flutter-release.yml`. iOS distribution must be signed and archived on macOS with Xcode and the Apple Developer account.

For a local Android debug build on this Windows workspace, use an ASCII-only Flutter SDK path because Gradle can misread the Japanese workspace path:

```powershell
$env:Path = 'C:\flutter-sdk-clean\flutter\bin;' + $env:Path
flutter build apk --debug --no-pub
```

The production app deliberately stops at a configuration screen when `APP_ENV=production` is built without Supabase credentials, so an accidentally unconfigured release cannot appear to work with local demo data.

Media uploads are limited to 500 MB per file in the client foundation. Production video transcoding and adaptive delivery remain required before accepting large-scale creator uploads.

### CI secrets required before a store build

Configure these as repository or environment secrets in the release workflow:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- Android signing material represented by `android/key.properties` (or equivalent CI secret files)

The first two are passed only as `--dart-define` values during the production build. Android signing files and passwords must remain outside source control. iOS signing additionally requires an Apple Developer certificate, provisioning profile, and a macOS/Xcode archive step.

## Applying Supabase migrations

Apply the SQL files in numeric order (`001` through `013`) in the Supabase SQL editor or through the Supabase CLI after configuring the project link. Never apply them out of order, and never commit real values from `.env`.

## Schema migrations

- `supabase/001_initial_schema.sql`: core profiles, posts, reactions, follows, audio, notifications, reports, and revenue ledger.
- `supabase/002_social_runtime.sql`: view events, direct messages, admin action audit, subscription records, indexes, and hardened RLS policies.
- `supabase/003_counters_notifications.sql`: server-side reaction/view counters and follow/reaction notifications.
- `supabase/004_privacy_blocks.sql`: profile creation rules, block lists, notification updates, audio access, and followers-only visibility.
- `supabase/005_user_settings_safety.sql`: age/safety metadata, notification preferences, themes, and default user settings.
- `supabase/006_creator_analytics.sql`: creator analytics RPC, platform fee rate, and server-side revenue split calculation.
- `supabase/007_auth_media_foundation.sql`: automatic profile creation after signup and private media storage ownership policies.
- `supabase/008_notifications_realtime.sql`: registers notifications for Supabase Realtime delivery.
- `supabase/009_revenue_ledger_policies.sql`: allows creators to read their own revenue ledger and admins to manage it.
- `supabase/010_recommendation_rpc.sql`: ranks visible posts using follows, engagement, and freshness.
- `supabase/011_profile_privacy_visibility.sql`: enforces private-profile visibility in the database.
- `supabase/012_admin_moderation_policies.sql`: restricts report review and moderation actions to admins.
- `supabase/013_account_deletion.sql`: account deletion request, 30-day grace period, and cancellation foundation.
