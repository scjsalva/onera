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

Accounts are invite-only and an invitation needs a member to send it, so an
empty deployment has no way in at all. It offers one, once: the sign-in page
says **Nobody has set this up yet** and lets you create the first account with
no link and no shell.

That offer disappears the moment an account exists, and not because of a
setting or a date — the condition it depends on can never come back. Posting
straight at the URL afterwards is refused too, including by a second person
racing for it.

Everybody after you comes in on a link you send from **You → People**, or from
a group's People tab to land them straight in that group.

If you ever need to let somebody in without sending them a link yourself —
onboarding a person you have not added — there is still:

    ./bin/rails onera:invite            # capped at 10 uses, expires in 7 days
    ./bin/rails onera:revoke_invites    # closes it early

That prints a link but adds no button to the sign-in page.

### On verifying accounts

There is no email verification, and adding one would mean an SMTP provider —
the same cost that put recovery codes in place of a password-reset email. It
would also buy little: anyone can verify a throwaway address, so it filters
robots rather than strangers.

The real control is that there is no open door. After the first account, the
only way in is a link somebody chose to send you.

Email is still asked for on every sign-in until given, and is required before
recovery codes can be issued, because that is the one thing that gets an
account back.

## 4. Making yourself the owner (alternative)

If you would rather not use the front door — say you are scripting a deploy —
the Render **Shell** tab still works:

    ./bin/rails onera:owner ONERA_NAME='Your Name' ONERA_USERNAME=yourname

It prints a generated password once. You cannot pass one in, on purpose: a real
password should never sit in a shell history or a deploy log.

## 5. Keeping it awake

Render spins a free service down after about fifteen minutes idle, and the next
visitor waits 40-90 seconds for the container to come back.

**Not with GitHub Actions.** That was tried and does not work: scheduled
workflows are best-effort, get dropped under load, and in eight hours inside
the active window not one of them fired. They are not a timer. On a private
repository they would also be metered - per job, rounded up to a whole minute,
so a ten-minute ping costs about 3,100 minutes against an allowance of 2,000 -
which makes it a trap waiting for the day somebody flips the repo to private.

Use a cron service, where the request is free and actually happens:

1. https://cron-job.org — free, no card.
2. New cron job, URL `https://onera-yqv9.onrender.com/up`.
3. Every **12 minutes**. Render's idle timer is fifteen, so three minutes of
   slack absorbs a late run.
4. Restrict the hours to **07:00-23:59**, your timezone.
5. Turn on failure notifications. It then doubles as uptime monitoring: if the
   app is down, the thing already watching it tells you.

Seventeen hours a day is **527 instance-hours** in a 31-day month against a
free allowance of **750**. Round the clock would be 744 - six hours of margin,
shared with the second instance a deploy briefly runs - and exceeding the
allowance suspends the service until the month turns. The overnight gap is what
buys the margin, and the cost is one slow visit each morning.

UptimeRobot works too, on a fixed five-minute interval; use its maintenance
windows for the overnight gap.

Whatever you pick, the pinger is load-bearing and fails quietly. The failure
notifications in step 5 are what make that visible - without them you find out
because the app got slow again.

## A region note

Keep the database in the same region as the web service — `render.yaml` says
Singapore, so the Neon project should be Singapore too.

Your latency to the app is one round trip per page. The app's latency to the
database is multiplied by every query on that page: at 36 queries, a database
one ocean away turns a 70 ms page into an eight-second one. Co-locating the two
matters far more than either being near you.

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
