# Testing Packaging

This repository is to test out building an artifact and
packaging it in a variety of formats, while also providing a
repository for some package managers, such as Homebrew Casks.

## Goals

* [x] Produce artifacts (tar.gz, zip) of OS/architecture-specific packages
    * [ ] Verify
* [x] GPG signed
* [x] Build an RPM package
    * [ ] Verify
* [x] Build a DEB package
    * [ ] Verify
* [ ] Provide an Arch Linux `PKGBUILD` and repository
    * [ ] Verify
* [ ] Upload the artifacts to S3
* [ ] Produce an RPM repository on S3
    * [ ] Verify
* [ ] Provide a DEB repository on S3
    * [ ] Verify
* [ ] Provide a Homebrew Cask repository
    * [ ] Verify

## Tools

* [GoReleaser](https://goreleaser.com/)
* [fpm](https://github.com/jordansissel/fpm) (RPM and DEB packages)

## Build

```shell
go build -o pkg/hello-world .
```
