[![Docker Image](https://img.shields.io/badge/docker%20image-available-green.svg)](https://hub.docker.com/repository/docker/ryanwhowe/svn-proxy/) ![Docker Pulls](https://img.shields.io/docker/pulls/ryanwhowe/svn-proxy) ![Docker Image Version](https://img.shields.io/docker/v/ryanwhowe/svn-proxy)

# svn-proxy

Apache and Subversion in a Debian-based Docker container, serving repositories over HTTP/WebDAV behind a reverse proxy. Images are available on Docker Hub as `ryanwhowe/svn-proxy`.

## Build and test

```bash
docker build --pull -t subversion:latest .
bash tests/smoke.sh subversion:latest
```

The smoke test requires Bash, Docker, and curl on the host. It creates a disposable container and removes it afterward. It checks Apache configuration, the root redirect, authentication, checkout and commit, read-only authorization, compressed dump/restore, and container logs.

Pull requests run these checks for `linux/amd64`, `linux/arm64`, `linux/riscv64`, `linux/ppc64le`, `linux/s390x`, and `linux/arm/v7`, using QEMU where needed. Pushes to `main` publish only after all platforms pass. Images receive both `latest` and `sha-<full Git commit SHA>` tags; use a SHA tag or image digest for a specific deployment and rollback target. ARMv6 is not supported by the current base image; separate AMD64 v2/v3 images are not published.

## Deployment

Copy `compose.yaml` and `compose.override.example.yaml` to the deployment directory, then rename the example to `compose.override.yaml`. Configure the reverse proxy's network or uncomment the port mapping in the override as appropriate.

```bash
docker compose config --quiet
docker compose up -d
docker compose logs -f svn
```

Compose uses the published image by default. To run a local build or pin a deployment, set the image in `compose.override.yaml`:

```yaml
services:
  svn:
    image: subversion:latest # Or ryanwhowe/svn-proxy:sha-<full Git commit SHA>
```

Terminate HTTPS at the reverse proxy to protect Basic authentication, and restrict direct access to the container's HTTP port. Verify checkout, commit, and server-side copy through the public proxy URL before production use. Apache redirects only `/` to `/svn/`, using a relative redirect to preserve the public scheme and host, and writes access and error logs to container output.

## Create a repository and users

Replace `example` and `alice` below with your repository and username. New volumes have a repository directory owned by Apache's `www-data` user. For an existing volume, check ownership first; if necessary, correct the intended directory or repository while no writes are occurring:

```bash
docker compose exec svn chown www-data:www-data /var/lib/svn/repos
# For an existing repository created as root:
docker compose exec svn chown -R www-data:www-data /var/lib/svn/repos/example
```

Create and load repositories as `www-data` so Apache can write to them:

```bash
docker compose exec --user www-data svn svnadmin create /var/lib/svn/repos/example
docker compose exec svn htpasswd /var/lib/svn/access/svnpass alice
docker compose exec svn vim /var/lib/svn/access/svnauth
```

Add an authorization rule to `svnauth`:

```ini
[example:/]
alice = rw
```

Use `r` for read-only access, `rw` for read/write, and an empty value to deny access. All access requires authentication. Keep both access files readable by Apache and credentials out of Git. Repositories and access files persist in the `svnData` volume mounted at `/var/lib/svn`.

## Backup and restore

Use `-T` for all redirected data streams to disable terminal allocation. Store backups outside the container and protect them as sensitive data.

Create a plain dump or a compressed dump:

```bash
docker compose exec -T svn svnadmin dump --quiet /var/lib/svn/repos/example > example.dump

# Run pipelines under Bash with pipefail so a failed dump is reported.
set -o pipefail
docker compose exec -T svn svnadmin dump --quiet /var/lib/svn/repos/example | gzip -9 > example.dump.gz
```

Create an empty destination repository, then load either format (choose one):

```bash
docker compose exec --user www-data svn svnadmin create /var/lib/svn/repos/restored
docker compose exec -T --user www-data svn svnadmin load /var/lib/svn/repos/restored < example.dump

# Alternative for a compressed dump:
gunzip -c example.dump.gz | docker compose exec -T --user www-data svn svnadmin load /var/lib/svn/repos/restored
```

Verify the restored repository with `svnadmin verify` and a checkout; add its authorization rule before HTTP access. Dumps contain versioned repository history, but do not include access files, hooks, or repository configuration. Back those up separately. For a complete volume archive, stop the service before copying the volume, preserve ownership and permissions, and test restoration into a separate volume. Do not use `docker compose down -v` on a deployment whose data you intend to keep.
