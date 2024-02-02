# Testing Packaging

This repository is to test out building an artifact and
packaging it in a variety of formats, while also providing a
repository for some package managers, such as Homebrew Casks.

## Goals

* Produce artifacts (tar.gz, zip) of OS/architecture-specific packages
* Build an RPM package
* Build a DEB package
* Provide an Arch Linux `PKGBUILD` and repository
* Produce an RPM repository on S3
* Provide a DEB repository on S3
* Provide a Homebrew Cask repository

* Upload the artifacts to S3

## Tools

* goreleaser
* fpm (RPM and DEB packages)

## Build

```shell
go build -o pkg/hello-world .
```
