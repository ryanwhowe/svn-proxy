[![Docker Image](https://img.shields.io/badge/docker%20image-available-green.svg)](https://hub.docker.com/repository/docker/ryanwhowe/svn-proxy/) ![Docker Pulls](https://img.shields.io/docker/pulls/ryanwhowe/svn-proxy) ![Docker Image Version](https://img.shields.io/docker/v/ryanwhowe/svn-proxy)


# svn-proxy

svn docker container runing webDav access via http, intented for use behind a proxy.  This is available on DockerHub [ryanwhowe/svn-proxy](https://hub.docker.com/repository/docker/ryanwhowe/svn-proxy/).  But if you need to alter the settings files for apache it is simple enough to build it yourself.

## Build the SVN 

Once in the solution directory run the docker build command to build the current version of the solution.

```bash
docker build -t subversion:latest .
```

## Setup

Copy the `compose.override.example.yaml` to `compose.override.yaml` and the `compose.yaml` to the deployment location.  Override the environment variables for your needs.

```bash
docker compose up -d
```

Once the container is running we will need to create a repository and the user and the permissions

Add a new Repository

```bash
docker compose exec svn sh -c "svnadmin create /var/lib/svn/repos/{reponame}"
```

Add the user to the password file

```bash
docker compose exec svn sh -c "htpasswd /var/lib/svn/access/svnpass {username}"
```

Add the user to the access file [see svnBook](https://svnbook.red-bean.com/en/1.7/svn.serverconfig.pathbasedauthz.html) for documentation on how to perform that.
```bash
docker compose exec svn sh -c "vim /var/lib/svn/access/svnauth"
```

access can be `r`, ` `, or `rw` ... ` ` is used to give NO access.

```text
[{reponame}:{path}]
{username}={access}
```

Load a dump file, here are two different ways to pipe the dump file content into the container's load command.

```bash
docker compose exec -T svn sh -c "svnadmin load /var/lib/svn/repos/{reponame}" < {backupName}.dump

cat {backupName}.dump | docker compose exec -T svn sh -c "svnadmin load /var/lib/svn/repos/{reponame}"
```

Dump the repo from inside the container to a local external `dump` file

```bash
docker compose exec svn sh -c "svnadmin dump --quiet /var/lib/svn/repos/{reponame} " > {backupName}.dump
```

Dump the repo from inside the container to a local external `dump` file, while streaming it though gzip.

```bash
docker compose exec svn sh -c "svnadmin dump --quiet /var/lib/svn/repos/{reponame} | gzip -9 " > {backupName}.dump.gz
```

Pipe in dump data through gzip into the container.

```bash
docker compose exec -T svn sh -c "gunzip | svnadmin load /var/lib/svn/repos/{reponame}" < {backupName}.dump.gz

```