# Deploying Onera

One Rails container and a PostgreSQL database. No Redis, no object storage, no
background workers, nothing written to disk — so anything that can run a
container and reach Postgres will do.

It cannot go on GitHub Pages: Pages serves static files, and this needs a Ruby
process and a database.

## The shape of it

**An Oracle Cloud always-free VM** runs the container behind Caddy, which
holds the TLS certificate. **Neon** holds the database.

Oracle's free tier has no clock on it and the machine never sleeps, which is
why it is here rather than a free PaaS — those idle out after a quarter of an
hour and the next visitor waits most of a minute for the app to wake.

The database is deliberately not on the same box. Neon backs it up and can be
reached from anywhere, so losing the machine costs an afternoon of setup
rather than everyone's records.

The image is built by GitHub Actions and pulled from the registry. The
always-free micro has 1 GB of memory and building the image on it — bundle
install and the Vite build together — exhausts that.

    GitHub Actions ──build──> ghcr.io/scjsalva/onera:latest
                                        │ pull
                                        v
                         Oracle VM: Caddy ──> Rails ──> Neon

## What you need first

1. **A Neon project** — https://neon.com, sign in with GitHub. Create a
   project in the region nearest you and copy the connection string. Keep the
   `?sslmode=require` on the end; Neon refuses unencrypted connections, which
   is what you want for a database holding other people's money.

2. **An Oracle Cloud account** — https://cloud.oracle.com. It asks for a card
   to verify identity and does not charge it, but check that for yourself
   before you type it in. Create an **Always Free** compute instance:
   - Ubuntu 24.04
   - Shape: `VM.Standard.A1.Flex` (ARM, 4 cores / 24 GB) if the region has
     capacity, otherwise `VM.Standard.E2.1.Micro` (1 core / 1 GB). Either
     works — the image is built for both — and the micro is always available.
   - Save the SSH private key it offers. It is the only copy.
   - Note the public IP.

3. **A hostname pointing at that IP.** A certificate needs a name, not an
   address. Two free ways:
   - `sslip.io` — no signup at all: an IP of `152.70.1.2` is already
     `152-70-1-2.sslip.io`.
   - DuckDNS — a nicer name like `onera.duckdns.org`, one GitHub sign-in.

4. **A registry token** — a GitHub personal access token with `read:packages`,
   so the box can pull a private image.

## Opening the ports

Oracle blocks inbound traffic in two separate places and you have to open
both. Missing the second is the most common way this fails.

1. **The console**: Networking → Virtual Cloud Networks → your VCN → the
   public subnet → its security list → add ingress rules for TCP 80 and 443
   from `0.0.0.0/0`.
2. **The machine itself**: Oracle's Ubuntu image ships an iptables ruleset
   that rejects everything but SSH. `deploy/setup.sh` handles this.

## Running it

    scp -i <your-key> deploy/setup.sh ubuntu@<ip>:/tmp/
    ssh -i <your-key> ubuntu@<ip>

    sudo ONERA_HOST=onera.duckdns.org \
         ACME_EMAIL=you@example.com \
         DATABASE_URL='postgres://...neon.tech/neondb?sslmode=require' \
         GHCR_USER=scjsalva \
         GHCR_TOKEN=ghp_... \
         bash /tmp/setup.sh

It installs Docker, opens the firewall, adds a 2 GB swapfile — 1 GB with no
swap means the first memory spike kills the container instead of slowing it
down — writes `/opt/onera/.env`, pulls the image and starts it. Caddy gets a
certificate on first boot and renews it on its own.

Run it again any time. Every step checks before it acts, so it doubles as the
repair script.

`SECRET_KEY_BASE` is generated once and then kept. Changing it signs everyone
out and invalidates every session cookie, so a re-run never regenerates it.

## The first account

Nothing is seeded but reference data — currencies, categories, exchange rates.
There are no accounts and no passwords in the image.

    cd /opt/onera
    docker compose exec web ./bin/rails onera:owner \
      ONERA_NAME='Your Name' ONERA_USERNAME=yourname

It prints a generated password once. You cannot pass one in on purpose: a real
password should never sit in a shell history or a deploy log. Sign in, change
it, then invite everyone else from **You → People**.

## Updating

Pushing to `main` builds a new image. On the box:

    cd /opt/onera && docker compose pull && docker compose up -d

Migrations run on boot.

## Day to day

    docker compose logs -f web          # what it is doing
    docker compose ps                   # what is running
    docker compose restart web          # turn it off and on again
    docker compose exec web ./bin/rails console

Recovering an account, from the same directory:

    docker compose exec web ./bin/rails onera:password ONERA_USERNAME=someone
    docker compose exec web ./bin/rails onera:codes ONERA_USERNAME=someone

## Checking a deploy before you make it

The image can be run by hand against any Postgres, which is how the Thruster
bug was caught — it started fine in every test and could not boot as a
container.

    docker build -t onera .
    docker run -p 3200:80 \
      -e SECRET_KEY_BASE=$(openssl rand -hex 64) \
      -e DATABASE_URL=postgres://... \
      -e APP_HOST=localhost:3200 onera

## If it does not come up

- `curl -I http://<ip>` times out → a firewall. Both places, see above.
- Caddy logs `could not get certificate` → the hostname does not resolve to
  the machine yet, or port 80 is closed. Let's Encrypt needs 80 to answer.
- `web` restarting → `docker compose logs web`. A bad `DATABASE_URL` is the
  usual cause; check the `?sslmode=require` survived the copy and paste.
- 403 on every page → `APP_HOST` does not match the name in the address bar.
  Rails' host allowlist is refusing it.
