# 🚧 Packaging Proving Ground 🚧

This repository is to test out building an artifact and
packaging it in a variety of formats, while also providing native package
repositories.

This project is developed around shipping a compiled Go binary and uses
[GoReleaser](https://goreleaser.com/) to produce the artifacts. The
functionality beyond the package creation should be fairly generic. I intend to
create a separate project with the same goals but building artifacts more
generically (without GoReleaser) instead.

All of this is an effort to better understand the packaging and distribution of
software in popular package repositories and formats.

## Overview

* Binary in `.tar.gz` and `.zip` archives for each platform
* RPM, DEB, AUR, PKGBUILD, APK, Homebrew packages
* Package repositories with browseable indexes
* GPG-signed artifacts
* Repo GPG support

## Goals

* Monorepo
    * I'm not opposed to separating things and think it might be necessary for
      certain things, or at least simpler and easier to deal with. However, I'd
      like to "prove out" a monolithic repository for managing the distribution
      alongside the source code.
* Re-usable
    * The methods and tools should be as re-usable as possible, given their
      intentional design choices. Minimal adaptation should be required to port
      this project's resources to another project.
* Avoid CI-specifics
    * This project should be able to produce the packages and repository
      structure locally as much as possible.
* Follow standards
    * Each package should follow the standards and conventions for that
      particular package and repository type. E.g. naming conventions,
      repository structure.

## Tools

* [GoReleaser](https://goreleaser.com/) does most of the work - compiles the
  binary, packages it (including distro packages), signs it, and does some of
  the publishing (Docker, GitHub releases).
* [web-indexer](https://github.com/joshbeard/web-indexer) is used to generate
  index pages for the web repo.

## Usage

The [`build.sh`](build.sh) script drives this thing. I started with a
`Makefile`, but shell was more readable and cleaner. I'm using this for local
development and in the GitHub pipeline.

To build all the packages, generate repositories, and stage things under
`dist/staging/`, run the following:

```shell
./build.sh snapshot
```

To do a "production" release (the [`CI job`](.github/workflows/ci.yml) runs
this).

```shell
./build.sh release
```

## Installing the Packages

This sections describes how to install the packages that this repository
produces.

### RPM Packages

You can download the `.rpm` files directly from the
[GitHub Releases](https://github.com/joshbeard/testing-packaging/releases),
<https://get.jbeard.dev/rpm>, or add the repository (recommended):

Add this to `/etc/yum.repos.d/jbeard.repo`:

```plain
[helloworld]
name=Hello World
baseurl=https://get.jbeard.dev/rpm/$basearch
enabled=1
gpgcheck=1
gpgkey=https://get.jbeard.dev/gpg-pubkey.asc
```

```shell
dnf install hello-world
```

### DEB Packages

You can download the `.deb` files directly from the
[GitHub Releases](https://github.com/joshbeard/testing-packaging/releases),
<https://get.jbeard.dev/deb/pool/main>, or add the repository (recommended):

__Add GPG Key__

```shell
wget -qO- https://get.jbeard.dev/gpg-pubkey.asc | gpg --dearmor > jbeard-repo-keyring.gpg
cat jbeard-repo-keyring.gpg | sudo tee /etc/apt/keyrings/jbeard-repo-keyring.gpg > /dev/null
```

__Add Repository__

```shell
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/jbeard-repo-keyring.gpg] https://get.jbeard.dev/deb stable main" |> \
    sudo tee /etc/apt/sources.list.d/jbeard.list
```

__Update APT sources and Install__

```shell
sudo apt update
sudo apt install hello-world
```
