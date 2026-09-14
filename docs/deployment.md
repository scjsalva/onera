# Deploying Onera

The app is a single Rails container plus a PostgreSQL database. Anything that
can run a Dockerfile and reach Postgres will do.

It cannot go on GitHub Pages: Pages serves static files, and this needs a Ruby
process and a database.

## The free combination

**Render** for the web service, **Neon** for the database. Both have a free
tier that needs no card, and together they cost nothing.

Render's own free Postgres is deliberately not used — it expires after 30 days
and takes the data with it. Neon's free tier persists indefinitely.

### 1. The database (Neon, ~2 minutes)

1. Sign up at https://neon.tech with GitHub.
2. Create a project — any name, pick the region nearest you.
3. Copy the connection string. It looks like:
   `postgresql://user:pass@ep-xxx.ap-southeast-1.aws.neon.tech/neondb?sslmode=require`

Keep `?sslmode=require`. Neon refuses unencrypted connections, which is what
you want for a database holding other people's money.

Neon scales an idle database to zero and wakes it on the next query, so the
first request after a quiet period is a little slow. Nothing is lost.

### 2. The web service (Render, ~3 minutes)

1. Sign up at https://render.com with GitHub.
2. **New → Blueprint**, choose `scjsalva/onera`. It reads `render.yaml`.
3. It will ask for the two values marked `sync: false`:
   - `DATABASE_URL` — the Neon string from step 1
   - `APP_HOST` — the host Render assigns, e.g. `onera.onrender.com`
4. Deploy. The first build takes a few minutes; it compiles the Vite bundle
   inside the image.

On boot the container runs migrations and loads reference data (currencies,
categories, exchange rates). It does **not** create any accounts.

### 3. The first account

There is no public sign-up — people join through an invite link, and an invite
link comes from someone already inside. So the first account is made by hand:

```bash
# Render dashboard → your service → Shell
bin/rails runner '
  u = User.create!(name: "John Carlo Salva", username: "scjsalva",
                   password: "change-this-now", password_confirmation: "change-this-now")
  puts RecoveryCodeIssuer.call(user: u).codes
'
```

Sign in, change the password, add your email, then invite everyone else from
**You → People → Invite**.

To seed the demo dataset instead, set `SEED_DEMO_DATA=1` and redeploy once.

## Environment

| Variable | Needed | What it is |
| --- | --- | --- |
| `DATABASE_URL` | yes | Postgres connection string, with `sslmode=require` |
| `SECRET_KEY_BASE` | yes | Session signing key; Render generates one |
| `APP_HOST` | yes | The public hostname, for host authorization |
| `RAILS_SERVE_STATIC_FILES` | yes | No separate web server in front |
| `SEED_DEMO_DATA` | no | Set on the first deploy to load sample data |

## Other hosts

`fly.toml` is included and works the same way (`fly launch --no-deploy`, set
the same secrets, `fly deploy`). Fly asks for a card even on the free
allowance; Render does not.

Koyeb, Railway and Cloud Run all take the Dockerfile unchanged.

## What is not set up

**Email.** There is no mail service, and nothing sends any. Password recovery
uses offline codes from a person's profile instead, which is why the app is
useful the moment it is deployed rather than after a domain-verification
dance. Recovery is checked against a person's email address as an identifier,
not by sending anything to it.

**Backups.** Neon keeps a restore window on the free tier. For a personal app
holding a few thousand rows, `pg_dump` on a schedule is enough if you want
more than that.
