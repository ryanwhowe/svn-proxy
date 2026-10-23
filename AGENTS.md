# Repository Guidelines

## Project Structure & Module Organization

This repository packages Apache and Subversion in a Debian-based Docker image for use behind a reverse proxy.

- `Dockerfile` installs packages, enables SVN modules, and starts Apache.
- `settings/apache/` holds Apache configuration. `dav_svn.conf`, `000-default.conf`, and `container.conf` are copied into the image; `apache2.conf` is currently unused by the build.
- `tests/smoke.sh` checks the disposable container, including authentication and backup/restore.
- `compose.yaml` defines the `svn` service and persistent `svnData` volume.
- `.github/workflows/dockerimage.yml` builds and publishes images on pushes to `main`.

## Build, Test, and Development Commands

- `docker build -t subversion:latest .` builds the local image.
- `docker run --rm subversion:latest -t` checks Apache configuration using the image's Apache entrypoint.
- `cp compose.override.example.yaml compose.override.yaml` creates local deployment settings; uncomment the port mapping when needed.
- `docker compose config` validates the merged Compose configuration.
- `docker compose up -d` starts the deployment; `docker compose logs svn` inspects startup output.

Compose defaults to the published `ryanwhowe/svn-proxy:latest` image. To test local changes through Compose, set `services.svn.image: subversion:latest` in the override file.

## Coding Style & Naming Conventions

Match surrounding formatting: two-space YAML indentation, existing tab indentation in the virtual-host configuration, and uppercase Dockerfile instructions. Retain established Apache directive names and `.conf` filenames. Keep edits focused. No formatter or linter is configured.

## Testing Guidelines

Run `bash tests/smoke.sh subversion:latest` after building the image. The script checks Apache configuration, redirects, authentication, checkout/commit, read-only access, compressed backup/restore, and logs using a disposable container. No coverage threshold is configured. CI runs smoke tests for each supported platform on pull requests and before publishing from `main`. Include validation commands and results in pull requests.

## Commit & Pull Request Guidelines

History uses short descriptive subjects, such as `Adding -y to update`; no strict commit format is established. Use concise, action-oriented subjects. Pull requests should explain the change, relevant issue references, configuration impact, and validation results. Include screenshots only for visible page changes.

## Security & Configuration Tips

Keep credentials, SVN dumps, and repository data out of Git. Store repositories and access files under `/var/lib/svn` in the persistent volume. Terminate HTTPS at the reverse proxy to protect Basic authentication. Keep deployment-specific settings in the ignored `compose.override.yaml`.
