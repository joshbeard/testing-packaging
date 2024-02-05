# Testing Packaging

This repository is to test out building an artifact and
packaging it in a variety of formats, while also providing a
repository for some package managers, such as Homebrew Casks.

This project is developed around shipping a compiled Go binary and uses
[GoReleaser]() and [NFPM]()
to produce the artifacts. The functionality beyond the package creation should
be fairly generic. I intend to create a separate project with the same goals
but building artifacts more generically (without GoReleaser) instead.

All of this is an effort to better understand the packaging and distribution of
software in popular package repositories and formats.

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

### First

* [x] Produce artifacts (tar.gz, zip) of OS/architecture-specific packages
    * [x] Validation
    * [ ] TODO: contains README unexpectedly (maybe bundle main readme and license)
* [x] GPG signed
* [x] Build an RPM package
    * [x] Validation
* [x] Build a DEB package
    * [x] Validation
* [x] Provide an Arch Linux `PKGBUILD`
    * [ ] Validation
* [x] Upload the artifacts to S3
    * [x] Validation

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
  * TODO: s3/cloudfront default indexes (index.html)
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

The [`build.sh`](build.sh) script drives this thing. I started with a
`Makefile`, but shell was more readable and cleaner.

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

#### Archive Package Names

```plain
<package-name>_<version>_<os>_<architecture>
```

```plain
hello-world_1.2.3_linux_amd64.tar.gz
hello-world_1.2.3_linux_arm64.tar.gz
hello-world_1.2.3_windows_amd64.zip
```

#### RPM and DEB Package Names

```plain
<package-name>_<version>-<release-number>_<architecture>
```

For example:

```plain
hello-world_1.2.3-1_amd64   # DEB
hello-world_1.2.3-1_arm64   # DEB

hello-world_1.2.3-1_x86_64  # RPM
hello-world_1.2.3-1_aarch64 # RPM
```

## Observations

* Debian repos are a pain
