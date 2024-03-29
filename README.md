# Introduction

The OwnTone container offers a hassle-free solution for deploying the OwnTone media server. By encapsulating OwnTone and its dependencies in a container, users enjoy consistent deployment across various platforms.

This approach enhances reliability, simplifies version control, and allows users to focus on using OwnTone’s media server features rather than dealing with complicated installation processes.

[![Docker Pulls](https://img.shields.io/docker/pulls/owntone/owntone.svg)](https://hub.docker.com/r/owntone/owntone)
[![Docker Stars](https://img.shields.io/docker/stars/owntone/owntone)](https://hub.docker.com/r/owntone/owntone)
[![Docker Image Size](https://img.shields.io/docker/image-size/owntone/owntone)](https://hub.docker.com/r/owntone/owntone)

## Quick Start

If you can’t wait to run OwnTone, here is a quick start procedure. It implies that you already have a running [Docker](https://www.docker.com) or [Podman](https://podman.io) installation.

1. Create a minimal structure, assuming everything is in the home directory

    ```shell
    mkdir -p $HOME/OwnTone/{etc,media,cache}
    ```

2. Launch the container

    ```shell
    docker run -d \
      --name=OwnTone \
      --network=host \
      -e UID=$(id -u) \
      -e GID=$(id -g) \
      -v $HOME/OwnTone/etc:/etc/owntone \
      -v $HOME/OwnTone/media:/srv/media \
      -v $HOME/OwnTone/cache:/var/cache/owntone \
      --restart unless-stopped \
      docker.io/owntone/owntone:latest
    ```

## Releases

The OwnTone container comes in two flavours: the **production** (tag `latest`) and the **staging** (tag `staging`) releases.

The staging release is designed for users who seek access to the latest features or bug fixes, providing a platform for testing and experimentation. In contrast, the production release is characterised by heightened stability, making it suitable for environments where reliability is paramount.

## Deployment

The deployment procedure can be described in 2 main steps.

1. Setup: The creation of user and directories, and network that will be used by OwnTone.
2. Running: A set of commands and alternatives to start OwnTone.

## Setup

This OwnTone container needs a certain amount of parameters to be configured to work properly.
Mainly, the [user and group](#user-and-group) running OwnTone, the [directories](#directories) where the database containing the metadata and your media are located, and the [network](#network) on which it is connected.

### User and Group

OwnTone should run with a specific user that you have to create on the host. If you don’t specify any user identifier (`UID`) and group identifier (`GID`) (see section Run), then the user and group with identifier 1000 will be used.

### Directories

The following directories, should be set up.

- **Configuration directory** - contains the configuration of OwnTone (by default `/etc/owntone/`).
- **Media directory** - contains all the media which will be available to be streamed by OwnTone (by default `/srv/media`).
- **Cache directory** - indicates where the OwnTone database (`database.db`) is being located (by default `/var/cache/owntone`).

The above mentioned directories can all be changed to fit your context.

Furthermore, you must ensure that at least the cache directory is writable by the user and group identifiers provided at startup.
Depending on your configuration, the media directory might need to be writeable by the user and group identifiers provided at startup.

### Network

OwnTone needs some network access to stream the audio to the audio devices. You have two options:

A. Share the container host IP address (see Host Network Stack below), or
B. Create a separate network and have OwnTone to be considered as a separate host (see Separate Network below).

#### Host Network Stack

In the case you simply want to use the network of the container host, then you will need to use the [`host`](https://docs.docker.com/engine/reference/run/#network-settings) network mode.

#### Separate Network

In specific situations, it is expected to have a container to be considered as a separate "machine" on the network.
Thus, you won’t have any limitation on ports you are using and therefore, you also won’t have to worry about mapping ports.
It gives as well the opportunity to have multiple OwnTone instances running in the same network.

To create a new network, you can run the following command:

```shell
docker network create \
  --driver macvlan \
  --subnet=<subnet> \
  --gateway=<gateway> \
  --ip-range=<ip-range> \
  -o parent=<interface> \
  <name>
```

Where

- `<subnet>` The subnet of the new network.
- `<ip-range>` The range of IPs for the new network.
- `<gateway>` The gateway of for the new network.
- `<interface>` The name of the physical network interface of the host.
- `<name>` The name of the new network.

##### Example of Network Setup

In the example below, we use the `macvlan` driver attached to the physical interface `enp3s0`.
It allows us to use the subnet of the router which is `192.168.0.0/24` - `192.168.0.1` to `192.168.0.254`.
Moreover, the router is configured to lease IP addresses, through DHCP, from `192.168.0.2` to `192.168.0.127`.
Thus, the range of IPs leased by the router will not overlap with the range defined by the container network.
Indeed, the new network has an IP range from `192.168.0.192` to `192.168.0.222`.

```shell
docker network create \
  --driver macvlan \
  --subnet=192.168.0.0/24 \
  --gateway=192.168.0.1 \
  --ip-range=192.168.0.192/27 \
  -o parent=enp3s0 \
  intnet
```

## Running

There are multiple ways to start the OwnTone container.

1. Run Command
2. Compose Command
3. SystemD

### Run Command

The most direct way to start the OwnTone container is to use the [Docker Run](https://docs.docker.com/engine/reference/commandline/run/) command.

#### Command

```shell
docker run -d \
  --name=<container-name> \
  --network=<network>
  -e UID=<uid> \
  -e GID=<gid>
  -v <configuration-location>:/etc/owntone \
  -v <media-location>:/srv/media \
  -v <database-location>:/var/cache/owntone \
  --restart unless-stopped \
  docker.io/owntone/owntone:<tag>
```

Where

- `<container-name>` A unique name for the container.
- `<network>` The type of network you are choosing. It can be the name of the network (e.g., `intnet` as in the example above), or the network mode `host`.
- `<uid>` The identifier of the user that will start the OwnTone process.
- `<gid>` The identifier of the group that is attached to the OwnTone user.
- `<configuration-location>` The path where the configuration is stored.
- `<media-location>` The path where the media are stored. Be sure to provide at least read access to the user running OwnTone.
- `<database-location>` The path where the database is stored. Be sure to provide write access to the user running OwnTone.
- `<tag>` The tag identifies which release has to be deployed. There are two meta tags: `latest` for latest production release and `staging` for the latest staging release (for more information, see the section [Releases](#releases))

#### Example with Docker Run Command

```shell
docker run -d \
  --name=OwnTone \
  --network=host \
  -e UID=1000 \
  -e GID=1000 \
  -v /etc/owntone:/etc/owntone \
  -v /mnt/media:/srv/media \
  -v /var/cache/owntone:/var/cache/owntone \
  --restart unless-stopped \
  docker.io/owntone/owntone:latest
```

### Compose Command

The main difference between Run and Compose is that with Compose, you use a YAML file to configure the container instance.
Instead of running the Run command above - which can be extensively long - from a command line, all the configuration is stored in a YAML file.

#### Compose File

Hereunder, you have an example of a Compose file (`owntone.yaml`).

```yaml
---
version: "3.8"
services:
  owntone:
    image: docker.io/owntone/owntone:latest
    container_name: OwnTone
    network_mode: host
    environment:
      - UID=1000
      - GID=1000
    volumes:
      - /etc/owntone:/etc/owntone
      - /mnt/media:/srv/media
      - /var/cache/owntone:/var/cache/owntone
    restart: unless-stopped
```

#### Example with Docker Compose Command

```shell
docker compose -f owntone.yaml
```

### systemd

Once you have the container running, you might want to automate the start and stop of OwnTone with your system.
If your system runs [systemd](https://systemd.io), it might be useful to automate the start of OwnTone with a Unit file.
With `podman generate systemd`, you can create a scaffolding [unit file](https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html) that you will be able to adapt later on.

```shell
podman generate systemd --new --files --name <container-name>
```

## Build

For general instructions on how to build OwnTone, please follow the directions indicated [here](https://owntone.github.io/owntone-server/building/).

Nevertheless, if you want to create your very own version of the container image, you can use the existing existing continuous integration definitions for Azure or GitHub:

- **Azure** ./azure/workflows/container-image.yml
- **GitHub** ./github/workflows/container-image.yml

It is also possible to run the build command locally with `docker build` or `podman build`.

This can become handy if you have made a fork of OwnTone and want to test some new features you have implemented.

### Build Arguments

The Dockerfile can take a few build arguments:

- `PACKAGE_REPOSITORY` The URL of the Alpine Linux package repository. By default, the latest community stable packages are taken.
- `REPOSITORY_URL` The URL of the source code of OwnTone. By default, the official source code repository is considered.
- `REPOSITORY_BRANCH` The branch that will be used as the source code base.
- `REPOSITORY_COMMIT` The commit on which the build will be based.
- `REPOSITORY_VERSION` The version on which the build will be based.

#### Notes

- If both a commit (commit identifier) and a version are provided, the commit has precedence over the version.
- If none of the above (commit or version) are provided, the last commit of the specified branch is provided.
- If no branch is provided, the default `master` branch is used.
- If no URL for the repository is provided, the original OwnTone repository is used.

## Architectures

Currently, this containerisation supports the x86-64 architecture.

## Contribution

If you want to contribute to make this containerisation better, please open a work item [here](https://github.com/owntone/owntone-container/issues).
