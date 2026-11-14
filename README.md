# SIBNTV

Stories worth streaming.

## Runtime
Node.js 20+ HTTP application deployed to Render. GitHub is the source of truth.

## Firebase architecture
SIBNTV uses Firebase Authentication for viewer accounts, Cloud Firestore for application records, and Firebase Storage for creator media and artwork. The Render server uses Firebase Admin SDK to verify ID tokens and perform trusted operations.

### Render environment variables

Browser Firebase configuration (public configuration values):
- `FIREBASE_API_KEY`
- `FIREBASE_AUTH_DOMAIN`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_STORAGE_BUCKET`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_APP_ID`

Server-only credential:
- `FIREBASE_SERVICE_ACCOUNT_JSON` — the complete Firebase service-account JSON, stored as a secret in Render. It may be supplied as raw JSON or base64-encoded JSON. Never put this value in browser code or GitHub.

The public web config is not an authorization secret. Firebase Security Rules and server-side ID-token verification enforce access. Do not use a service-account key in client code.

## Firebase setup
1. Create a dedicated Firebase project for SIBNTV.
2. Enable Email/Password in Authentication.
3. Create a Cloud Firestore database.
4. Enable Cloud Storage and choose the project's storage location.
5. Register a Web App and copy its config values into the Render environment.
6. Create a service account in Firebase Project Settings > Service Accounts. Store its JSON securely as `FIREBASE_SERVICE_ACCOUNT_JSON` in the Render preview service first.
7. Deploy Firestore and Storage rules from `firestore.rules`, `storage.rules`, and `firebase.json` using Firebase CLI after selecting the correct SIBNTV project.
8. Assign creator/admin roles only through a trusted administrative process. New accounts are viewers by default.

## Data model
- `profiles/{uid}` — display name, avatar, role and timestamps.
- `titles/{titleId}` — creator-owned drafts and published catalogue records.
- `creatorChannels/{channelId}` — creator channels and review status.
- `users/{uid}/watchlist/{titleId}` — saved titles.
- `users/{uid}/playbackHistory/{eventId}` — viewing progress.
- `subscriptions/{subscriptionId}` — provider-backed subscription state.
- `mediaAssets/{assetId}` — media processing and delivery metadata.

## API
- `GET /health`, `GET /api/health` — service health.
- `GET /api/config` — Firebase configuration readiness (no secrets).
- `GET /api/me` — authenticated profile; requires `Authorization: Bearer <Firebase ID token>`.
- `GET /api/content` — published Firestore catalogue.
- `POST /api/content` — creator/admin draft creation; requires Firebase ID token.
- `GET /api/creator/dashboard` — creator-only metrics.
- `GET /api/admin/dashboard` — admin-only metrics.

## Local development
```bash
npm install
npm start
``
The server listens on `PORT` (defaults to 3001).

## Still requiring provider setup
Creator media upload UX, transcoding, HLS/DASH playback, live ingest/egress, CDN delivery, subscription checkout and verified payment webhooks are separate integrations. Firebase Storage is an upload store, not a video transcoding or live streaming service. No live broadcast or paid subscription should be represented as active until its provider and webhook verification are implemented.

## Legacy Supabase work
The earlier Supabase SQL migration is retained for historical reference only. It is not used by the Firebase runtime and must not be applied to Firebase.

## Migration safety
The prior Railway project, PostgreSQL database and Redis volumes remain untouched. No Railway data has been exported, migrated or deleted. Any legacy records require a verified export and an explicit mapping/import process.
