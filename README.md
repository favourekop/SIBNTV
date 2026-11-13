# SIBNTV

Stories worth streaming.

## Runtime

Node.js 20+ HTTP application deployed to Render. The GitHub repository is the source of truth.

## Run locally

```bash
npm start
```

The server listens on `PORT` (defaults to 3001).

## Render environment

Configure these in the SIBNTV Render service's Environment settings:

- `SUPABASE_URL` — SIBNTV Supabase project URL.
- `SUPABASE_ANON_KEY` — Supabase publishable/anon key for browser authentication.
- `SUPABASE_SERVICE_ROLE_KEY` — server-only key for trusted administrative jobs. Never expose this key in browser code or commit it to GitHub.

Do not reuse credentials from another project. The service currently runs in preview mode until the SIBNTV Supabase project is configured.

## Supabase database foundation

The initial schema is in `supabase/migrations/202611130001_initial_schema.sql`. It creates profiles, catalogue titles, watchlists, creator channels, subscriptions and playback events, with row-level security policies.

Review and apply the migration in the dedicated SIBNTV Supabase project before connecting production traffic. Creator/admin role assignment must happen through a trusted server-side operation using the service role key; never allow a browser client to grant itself a privileged role.

## Current implementation status

- Responsive SIBNTV landing page and sample catalogue.
- Search, category filtering, title detail panels and browser-local My List.
- Supabase email/password auth UI, pending project credentials.
- Health and preview catalogue APIs.
- Creator Studio and Admin Console preview pages.
- Database schema foundation committed; database not yet connected.
- Live streaming, media storage/transcoding, playback delivery, billing and production creator/admin authorization remain to be integrated.

## Migration safety

The previous Railway project, PostgreSQL database and Redis volumes have not been modified. No Railway database contents have been migrated. A verified export or accessible source database is required before data migration.
