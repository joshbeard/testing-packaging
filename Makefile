# Makefile for building and releasing the hello-world application
#
# This requires goreleaser and nfpm to be installed.
# Use `make install-tools-go` to install them with `go install`.
#
# You can also start a shell in a container with `make shell` and run
# `make install-tools-go` there.
#
# Run `make dev-release` to build and package the application for testing.
# The contents will be in the `dist` directory.

# Define variables for versions
GORELEASER_VERSION := v1.23.0
NFPM_VERSION := v2.35.3

# Project-specific variables
BINARY_NAME := hello-world
PACKAGE_NAME := hello-world
# VERSION := 0.1.0

# Get the current Git tag for the version
VERSION := $(shell git describe --tags --abbrev=0)

STAGING_DIR := "dist/stage"

.PHONY: shell
shell:
	docker run --rm -it -v $(PWD):/go/src/github.com/$(PACKAGE_NAME) \
		-w /go/src/github.com/$(PACKAGE_NAME) golang:1.21 bash

.PHONY: install-tools
install-tools:
	go install github.com/goreleaser/goreleaser@$(GORELEASER_VERSION)
	go install github.com/goreleaser/nfpm/v2/cmd/nfpm@$(NFPM_VERSION)

.PHONY: goreleaser-snapshot
goreleaser-snapshot:
	goreleaser --snapshot --skip-publish --clean --skip-sign

.PHONY: goreleaser-release
goreleaser-release:
	goreleaser release --clean

.PHONY: nfpm
nfpm:
	envsubst < .nfpm.yaml >| .nfpm.yaml.tmp
	@NFPM_PKG_VERSION=$(VERSION)

	@for ARCHITECTURE in amd64:x86_64 arm64:aarch64; do \
		NFPM_PKG_ARCH=$$(echo $$ARCHITECTURE | cut -d: -f1); \
		FILENAME_ARCH=$$(echo $$ARCHITECTURE | cut -d: -f2); \
		FILENAME=$$FILENAME_ARCH/$(PACKAGE_NAME)-$(VERSION)-$$FILENAME_ARCH; \
		mkdir -p $(STAGING_DIR)/archlinux/$$FILENAME_ARCH; \
		mkdir -p $(STAGING_DIR)/deb/$$FILENAME_ARCH; \
		mkdir -p $(STAGING_DIR)/rpm/$$FILENAME_ARCH; \
		nfpm -f .nfpm.yaml.tmp package --packager rpm --target $(STAGING_DIR)/rpm/$$FILENAME.rpm; \
		nfpm -f .nfpm.yaml.tmp package --packager archlinux --target $(STAGING_DIR)/archlinux/$$FILENAME.pkg.tar.zst; \
		# deb uses arm64 instead of aarch64; fix it here \
		if [ "$$FILENAME_ARCH" = "aarch64" ]; then \
			FILENAME_ARCH=arm64; \
		fi; \
		nfpm -f .nfpm.yaml.tmp package --packager deb --target $(STAGING_DIR)/deb/$$FILENAME.deb; \
	done

.PHONY: all
all: goreleaser nfpm

.PHONY: clean
clean:
	rm -rf dist
	rm -f .nfpm.yaml.tmp

.PHONY: release
release: goreleaser-release stage nfpm

.PHONY: snapshot
snapshot: goreleaser-snapshot stage nfpm

.PHONY: stage
stage:
	echo "Staging release artifacts"
	@mkdir -p $(STAGING_DIR)/pkg/$(VERSION)
	@mv dist/*.zip dist/*.tar.gz $(STAGING_DIR)/pkg/$(VERSION)/
	@mv dist/checksums.txt $(STAGING_DIR)/pkg/$(VERSION)/
	@mv dist/aur $(STAGING_DIR)/

.PHONY: repo-rpm
repo-rpm:
	createrepo_c --update $(STAGING_DIR)/rpm/x86_64
	createrepo_c --update $(STAGING_DIR)/rpm/aarch64

.PHONY: createrepo-archlinux
createrepo-archlinux:
	repo-add --new --remove $(STAGING_DIR)/archlinux/x86_64/hello-world.db.tar.gz $(STAGING_DIR)/archlinux/x86_64/*.pkg.tar.zst
	repo-add --new --remove $(STAGING_DIR)/archlinux/aarch64/hello-world.db.tar.gz $(STAGING_DIR)/archlinux/aarch64/*.pkg.tar.zst

.PHONY: createrepo-deb
createrepo-deb:
	dpkg-scanpackages $(STAGING_DIR)/deb/amd64 /dev/null | gzip -9c > $(STAGING_DIR)/deb/amd64/Packages.gz
	dpkg-scanpackages $(STAGING_DIR)/deb/arm64 /dev/null | gzip -9c > $(STAGING_DIR)/deb/arm64/Packages.gz
