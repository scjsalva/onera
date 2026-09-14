#!/usr/bin/env bash
# Turns a fresh Oracle always-free Ubuntu box into the Onera server.
#
# Safe to run again: every step checks before it acts, so this doubles as the
# repair script when something drifts.
#
#   sudo ONERA_HOST=onera.example.com ACME_EMAIL=you@example.com \
#        DATABASE_URL=postgres://... GHCR_USER=scjsalva GHCR_TOKEN=ghp_... \
#        bash setup.sh
set -euo pipefail

APP_DIR=/opt/onera
: "${ONERA_HOST:?ONERA_HOST is required, e.g. onera.example.com}"
: "${ACME_EMAIL:?ACME_EMAIL is required for the certificate expiry warnings}"
: "${DATABASE_URL:?DATABASE_URL is required - the Neon connection string}"
: "${GHCR_USER:?GHCR_USER is required}"
: "${GHCR_TOKEN:?GHCR_TOKEN is required - a token with read:packages}"
IMAGE="${ONERA_IMAGE:-ghcr.io/scjsalva/onera:latest}"

say() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

say "packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq ca-certificates curl gnupg iptables-persistent >/dev/null

say "docker"
if ! command -v docker >/dev/null; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null
fi
systemctl enable --now docker >/dev/null

# Oracle's Ubuntu image ships an iptables ruleset that rejects everything but
# SSH, and it is not the security list in the console - opening the ports there
# is necessary but not sufficient. This is the half people miss.
say "firewall"
for port in 80 443; do
  if ! iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null; then
    iptables -I INPUT 5 -p tcp --dport "$port" -m state --state NEW,ESTABLISHED -j ACCEPT
    echo "  opened $port"
  else
    echo "  $port already open"
  fi
done
netfilter-persistent save >/dev/null 2>&1 || iptables-save > /etc/iptables/rules.v4

# 1 GB with no swap means the first memory spike kills the container rather
# than slowing it down.
say "swap"
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile >/dev/null
  swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  echo "  2G swapfile added"
else
  echo "  already present"
fi

say "application directory"
mkdir -p "$APP_DIR"
cd "$APP_DIR"

# Generated once and kept. Changing it signs everybody out and invalidates
# every session cookie, so it is never regenerated on a redeploy.
if [ -f .env ] && grep -q '^SECRET_KEY_BASE=' .env; then
  SECRET_KEY_BASE=$(grep '^SECRET_KEY_BASE=' .env | cut -d= -f2-)
  echo "  keeping the existing SECRET_KEY_BASE"
else
  SECRET_KEY_BASE=$(openssl rand -hex 64)
  echo "  generated a SECRET_KEY_BASE"
fi

umask 077
cat > .env <<ENV
SECRET_KEY_BASE=$SECRET_KEY_BASE
DATABASE_URL=$DATABASE_URL
APP_HOST=$ONERA_HOST
ACME_EMAIL=$ACME_EMAIL
ONERA_IMAGE=$IMAGE
ENV
umask 022

say "registry"
echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin

say "starting"
docker compose pull
docker compose up -d
docker image prune -f >/dev/null

say "waiting for the app"
for _ in $(seq 1 60); do
  if curl -fsS -o /dev/null http://localhost/up 2>/dev/null; then
    echo "  healthy"
    break
  fi
  sleep 2
done

if ! curl -fsS -o /dev/null http://localhost/up 2>/dev/null; then
  echo "  never came up. Recent logs:"
  docker compose logs --tail 40 web
  exit 1
fi

say "done"
echo "https://$ONERA_HOST"
echo
echo "Make the first account:"
echo "  cd $APP_DIR && docker compose exec web ./bin/rails onera:owner \\"
echo "    ONERA_NAME='Your Name' ONERA_USERNAME=yourname"
