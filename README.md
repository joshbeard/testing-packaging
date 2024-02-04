# Testing Packaging

This repository is to test out building an artifact and
packaging it in a variety of formats, while also providing a
repository for some package managers, such as Homebrew Casks.

## Goals

### First

* [x] Produce artifacts (tar.gz, zip) of OS/architecture-specific packages
    * [ ] Validation
* [x] GPG signed
* [x] Build an RPM package
    * [x] Validation
* [x] Build a DEB package
    * [x] Validation
* [x] Provide an Arch Linux `PKGBUILD`
    * [ ] Validation
* [x] Upload the artifacts to S3
    * [ ] Validation

### Second

* [x] Produce an RPM repository on S3
    * [x] Verify
* [ ] Provide a DEB repository on S3
    * [ ] Verify
* [ ] Provide a Homebrew Cask repository
    * [ ] Verify
* [ ] Arch AUR
    * [ ] Verify

### Third

* [ ] RPM repository GPG
* [ ] DEB repository GPG

### Fourth

* [ ] Directory indexes
* [ ] Serve install script for curl/wget by default for root request
* [ ] Changelogs
* [ ] Release pipeline/workflow
* [ ] Tests
    * Local web service serving `dist/stage/`
    * Test in Docker container
* [ ] Backups/Replication

### Future

* [ ] Submission to Arch community repo
* [ ] Submission to Homebrew main repo

### Other Ideas

* [ ] Lambda@Edge function for serving directory listings?
* [ ] FreeBSD port and package
* [ ] OpenBSD port and package

## Tools

* [GoReleaser](https://goreleaser.com/)
* [nFpm](https://nfpm.goreleaser.com/)
* [s3-indexer](tools/s3-indexer)

## Usage

To do a "production" release:

```shell
make release
```

To build and stage all artifacts under `dist/`:

```shell
make stage
```

### Use a Container

This can also be ran inside a container. Run `make shell` to launch a shell in
a container, and `make install-tools` from there to install _goreleaser_ and
_nfpm_.

## Build

```shell
go build -o pkg/hello-world .
```

## Installing the Packages

This sections describes how to install the packages that this repository
produces.

### Install the RPM

Add this to `/etc/yum.repos.d/jbeard.repo`:

```plain
[helloworld]
name=Hello World
baseurl=https://get.jbeard.dev/rpm/$basearch
enabled=1
gpgcheck=0
```

```shell
yum install hello-world
```

### Install the DEB

```plain
deb [trusted=yes] https://get.jbeard.dev/deb stable main
```

## Repository Structure and Naming Conventions

## Resources

### Building Debian Packages

* <https://wiki.debian.org/DebianRepository/Setup>
* <https://earthly.dev/blog/creating-and-hosting-your-own-deb-packages-and-apt-repo/>

### Package Name Conventions

#### Debian Package Names

```plain
<package-name>_<version>-<release-number>_<architecture>
```

## Observations

* Debian packages are a pain
