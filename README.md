# Horizon

Inventory, procurement and equipment booking for our rocketry team. An Android app (Flutter) backed by a small self-hosted [PocketBase](https://pocketbase.io) server.

## For members: install the app

1. On your Android phone, open **[Download Horizon](https://github.com/kavishraval8-RKT/Horizon_app/releases/latest/download/Horizon.apk)**.
   - Smaller download that works on almost every phone made since 2017: [Horizon-arm64.apk](https://github.com/kavishraval8-RKT/Horizon_app/releases/latest/download/Horizon-arm64.apk).
2. Open the downloaded file. Android will ask you to allow installs from your browser or Files app: allow it, then tap **Install**.
3. Log in with the email and password an admin gave you. You can change your password under **More → Account**.

When a new version comes out, the app tells you on launch. Tap **Download** and install it over the old one; your login and data stay.

## What it does

| Tab | Members | Admins |
|---|---|---|
| **Inventory** | Search parts, see stock levels and what's running low, check items out and back in, report damage with a photo | Add, edit (long-press) and delete items |
| **Progress** | Post daily progress and blockers, see your own history | See everyone's reports, filter by date and person |
| **Requests** | Ask for something to be bought, track its status | Approve, reject, mark ordered/delivered |
| **Ledger** | | Every check-out, return and damage report, with photos |
| **More → Services** | Book shared equipment (3D printer, drill press, ...) in time slots | Add and remove equipment |
| **More → Account** | Display name, change password, light/dark mode | |

## How it's built

```
horizon_app/    Flutter app (Android; also runs on web for previews)
backend/
  pb_migrations/  Database schema and access rules, applied automatically on start
  pb_hooks/       Server-side logic (stock counts, booking overlap checks)
  check_server.py Test suite for the rules and hooks (run against a throwaway server)
```

**Security model:** the app is untrusted; every rule is enforced on the server.

- Nothing is readable without logging in, and there is no public sign-up. Admins create accounts in the PocketBase dashboard.
- Members can't make themselves admin, act as another user, or edit stock counts directly.
- Stock changes only happen through ledger entries. A server hook validates each one and updates the count in the same database transaction.
- Booking overlaps are rejected the same way.

## For admins

**Add a member:** open the PocketBase dashboard (`https://horizon.streamharbor.me/_/`) → **users** → **New record**, then set `role` to `member` or `admin`.

**Run the backend locally**

```bash
cd backend
./pocketbase serve        # http://127.0.0.1:8090, dashboard at /_/
```

**Test the server rules** against a throwaway database. The script creates users and items, so never point it at production:

```bash
cd backend
./pocketbase superuser upsert su@test.local testpass123 --dir /tmp/pbtest
./pocketbase serve --dir /tmp/pbtest --http 127.0.0.1:8099
python check_server.py http://127.0.0.1:8099 su@test.local testpass123
```

**Release a new version**

1. Bump `version:` in `horizon_app/pubspec.yaml` (e.g. `1.3.0+4`).
2. Run `bash horizon_app/build_release.sh`. You need the signing key in `horizon_app/android/key.properties`; it is not in this repo.
3. Create a GitHub release tagged `v1.3.0` and attach `dist/Horizon.apk` and `dist/Horizon-arm64.apk`. Keep those exact file names; the download links depend on them.

**Deploy backend changes:** copy `pb_migrations/` and `pb_hooks/` to the server's `/opt/horizon/`, then restart the `pocketbase` service. New migrations apply on start.
