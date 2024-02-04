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

* [ ] Produce an RPM repository on S3
    * [ ] Verify
* [ ] Provide a DEB repository on S3
    * [ ] Verify
* [ ] Provide a Homebrew Cask repository
    * [ ] Verify
* [ ] Arch AUR
    * [ ] Verify

### Third

* [ ] Directory indexes
* [ ] Serve install script for curl/wget by default for root request

### Future

* [ ] Submission to Arch community repo
* [ ] Submission to Homebrew main repo
* [ ] FreeBSD port and package

### Other Ideas

* [ ] Lambda@Edge function for serving directory listings?

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
