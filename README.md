# SIBNTV

Stories worth streaming.

## Runtime

This repository contains the SIBNTV application source migrated from the existing Railway Bun function to a Node.js HTTP server for Render compatibility. The existing product UI and API routes are preserved.

## Run locally

```bash
npm start
```

The server listens on `PORT` (defaults to 3001).

## Environment

- `SUPABASE_URL` — optional Supabase project URL for authentication.
- `SUPABASE_ANON_KEY` — optional Supabase publishable/anon key.

The catalogue, creator studio, admin console, live streaming and billing still contain preview-only functionality. Configure and test each integration before enabling it for users.

## Migration note

The Railway project, PostgreSQL and Redis volumes have not been modified. Database data migration requires an accessible source database or a verified backup; the Railway database was offline during migration inspection.
