# Deploying Onera

One Rails container and a PostgreSQL database. No Redis, no object storage, no
background workers, nothing written to disk — so anything that can run a
container and reach Postgres will do.

It cannot go on GitHub Pages: Pages serves static files, and this needs a Ruby
process and a database.

## The shape of it

**Render** runs the container. **Neon** holds the database. Both free, neither
needs a card.

The database is deliberately not a Render Postgres: theirs is deleted after 30
days on the free plan. Neon's free tier has no such clock, backs itself up, and
survives the app being rebuilt or moved — which is the point. Losing the web
service should cost an afternoon, not everyone's records.

## 1. The database (~2 minutes)

1. Sign in at https://neon.com with GitHub.
2. Create a project in the region nearest you — Singapore for Manila.
3. Copy the connection string:
   `postgresql://user:pass@ep-xxx.ap-southeast-1.aws.neon.tech/neondb?sslmode=require`

Keep the `?sslmode=require`. Neon refuses unencrypted connections, which is
what you want for a database holding other people's money.

Neon suspends an idle database and wakes it on the next query, so the first
request after a quiet spell pays about half a second. Nothing is lost.

## 2. The web service (~5 minutes)

1. Sign in at https://render.com with GitHub.
2. **New → Blueprint**, connect GitHub, pick `scjsalva/onera`. It reads
   `render.yaml`. The one-click deploy URL will not work — the repository is
   private.
3. It asks for the two values marked `sync: false`:
   - `DATABASE_URL` — the Neon string above
   - `APP_HOST` — the host Render assigns, e.g. `onera.onrender.com`. You will
     not know it until the service exists; the app allows any `onrender.com`
     host for exactly that reason, so it works on the first deploy and you can
     fill this in straight after.
4. Deploy. The first build takes several minutes — it compiles the Vite bundle
   inside the image.

On boot the container runs migrations and loads reference data: currencies,
categories, exchange rates. **No accounts and no passwords.**

## 3. The first account

    Render dashboard → your service → Shell

    ./bin/rails onera:owner ONERA_NAME='Your Name' ONERA_USERNAME=yourname

It prints a generated password once. You cannot pass one in, on purpose: a real
password should never sit in a shell history or a deploy log. Sign in, change
it, then invite everyone else from **You → People**.

## 4. Keeping it awake

Render spins a free service down after about fifteen minutes idle, and the next
visitor waits 40–90 seconds for it to come back.

`.github/workflows/keepalive.yml` pings `/up` every ten minutes between 07:00
and 23:00 Manila. Set the URL it pings under **Settings → Secrets and variables
→ Actions → Variables**, as `ONERA_URL` — e.g. `https://onera.onrender.com`.

Sixteen hours a day is 496 instance-hours in a 31-day month against a free
allowance of 750. Round-the-clock would be 744, and exceeding the allowance
suspends the service until the month rolls over, so the overnight gap is what
buys the margin. The cost is one slow visit each morning.

Two things that make a keep-alive fail quietly:

- GitHub disables scheduled workflows after 60 days with no repository
  activity. If nothing has been pushed in two months, the pings stop and the
  app goes back to sleeping without telling anyone.
- Scheduled runs are best-effort and can be delayed by ten minutes or more
  under load, so the odd visitor will still meet a cold start.

## Nothing runs on GitHub

The repository is private and under a work-linked account, so nothing is left
running there on a schedule:

- **The keep-alive** is an external cron, for the reason above.
- **CI** is `workflow_dispatch` only — run it with `gh workflow run CI` when
  you want a clean-machine second opinion. `bin/check` is the real gate and
  does the same work locally in about a minute.
- **No container registry.** Render builds from the repository, so nothing is
  pushed to GitHub Packages and no storage quota applies.

Render's own build minutes cover the deploys — 500 a month on the free plan,
and a build takes a few.

## Updating

Pushing to `main` deploys, using Render's build minutes rather than GitHub's.
Migrations run on boot.

## Day to day

From the service's **Shell** tab:

    ./bin/rails console
    ./bin/rails onera:password ONERA_USERNAME=someone   # locked out
    ./bin/rails onera:codes ONERA_USERNAME=someone      # codes remaining

Logs are on the **Logs** tab.

## Checking a deploy before you make it

The image can be built and run against any Postgres. This is how the Thruster
bug was caught: the app started fine in every test and the container could not
boot at all.

    docker build -t onera .
    docker run -p 3200:80 \
      -e SECRET_KEY_BASE=$(openssl rand -hex 64) \
      -e DATABASE_URL=postgres://... \
      -e APP_HOST=localhost:3200 onera

## If it does not come up

- Build fails on assets → check the build log for the Vite step; it needs
  `package-lock.json` in the repository.
- `web` restarting → almost always `DATABASE_URL`. Check the
  `?sslmode=require` survived the copy and paste.
- 403 on every page → `APP_HOST` does not match the address bar. Rails' host
  allowlist is refusing it.
- Slow first visit → that is the spin-up. See "Keeping it awake".
