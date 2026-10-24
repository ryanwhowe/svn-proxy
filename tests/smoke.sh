#!/usr/bin/env bash
set -euo pipefail

image=${1:-subversion:latest}
container="svn-proxy-smoke-$$-${RANDOM}"
volume="${container}-data"

cleanup() {
  result=$?
  trap - EXIT
  if [ "$result" -ne 0 ]; then
    docker logs "$container" >&2 || true
  fi
  docker rm -fv "$container" >/dev/null 2>&1 || true
  docker volume rm "$volume" >/dev/null 2>&1 || true
  exit "$result"
}
trap cleanup EXIT

docker run --rm "$image" -t
docker volume create "$volume" >/dev/null
docker run -d --name "$container" -v "$volume:/var/lib/svn" -p 127.0.0.1::80 "$image" >/dev/null

docker exec -u www-data "$container" svnadmin create /var/lib/svn/repos/smoke
docker exec -u www-data "$container" svnadmin create /var/lib/svn/repos/restored
docker exec "$container" htpasswd -b /var/lib/svn/access/svnpass writer smoke-password
docker exec "$container" htpasswd -b /var/lib/svn/access/svnpass reader smoke-password
docker exec -i "$container" sh -eu <<'SETUP'
printf '[smoke:/]\nwriter = rw\nreader = r\n[restored:/]\nwriter = rw\n' > /var/lib/svn/access/svnauth
SETUP

port=$(docker port "$container" 80/tcp)
base="http://$port"
ready=false
for _attempt in {1..30}; do
  if curl --silent --fail --max-time 5 "$base/" -o /dev/null; then
    ready=true
    break
  fi
  sleep 1
done
[ "$ready" = true ]

headers=$(curl --silent --show-error -H 'Host: svn.example.test' -H 'X-Forwarded-Proto: https' -D - -o /dev/null "$base/")
printf '%s\n' "$headers" | tr -d '\r' | grep -E '^HTTP/1\.[01] 302 '
printf '%s\n' "$headers" | tr -d '\r' | grep -Ei '^Location: /svn/$'
[ "$(curl --silent --show-error -o /dev/null -w '%{http_code}' "$base/svn/smoke/")" = 401 ]
[ "$(curl --silent --show-error -u writer:wrong -o /dev/null -w '%{http_code}' "$base/svn/smoke/")" = 401 ]
curl --silent --show-error --fail -u writer:smoke-password "$base/svn/smoke/" >/dev/null

docker exec -i -u www-data "$container" sh -eu <<'CHECK'
svn_auth() {
  svn --non-interactive --no-auth-cache --username writer --password smoke-password "$@"
}
svn_auth checkout http://127.0.0.1/svn/smoke /tmp/smoke-wc
printf 'round-trip content\n' > /tmp/smoke-wc/example.txt
svn_auth add /tmp/smoke-wc/example.txt
svn_auth commit /tmp/smoke-wc -m 'Smoke test commit'
svn --non-interactive --no-auth-cache --username reader --password smoke-password \
  cat http://127.0.0.1/svn/smoke/example.txt > /tmp/read-content
cmp /tmp/smoke-wc/example.txt /tmp/read-content
echo 'Checking that a read-only user cannot write (a forbidden response is expected).'
if svn --non-interactive --no-auth-cache --username reader --password smoke-password \
  mkdir http://127.0.0.1/svn/smoke/denied -m 'Must be denied'; then
  echo 'Read-only user unexpectedly wrote to repository' >&2
  exit 1
fi
CHECK

# Exercise the same non-TTY binary stream used by documented backups.
docker exec "$container" bash -euo pipefail -c 'svnadmin dump --quiet /var/lib/svn/repos/smoke | gzip -9' \
  | docker exec -i -u www-data "$container" bash -euo pipefail -c 'gunzip | svnadmin load --quiet /var/lib/svn/repos/restored'
docker exec -u www-data "$container" svnadmin verify --quiet /var/lib/svn/repos/restored
docker exec -i -u www-data "$container" sh -eu <<'VERIFY'
[ "$(svnlook youngest /var/lib/svn/repos/restored)" = 1 ]
svnlook cat /var/lib/svn/repos/restored example.txt > /tmp/restored-content
cmp /tmp/smoke-wc/example.txt /tmp/restored-content
VERIFY
curl --silent --show-error --fail -u writer:smoke-password "$base/svn/restored/example.txt" >/dev/null
docker logs "$container" 2>&1 | grep -F 'GET /svn/smoke/' >/dev/null
echo 'Smoke tests passed: redirect, authentication, checkout, commit, authorization, backup/restore, and logs.'
