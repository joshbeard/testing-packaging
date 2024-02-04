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
RELEASE_NUM := $(shell git rev-list --count HEAD)

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
	@for ARCHITECTURE in amd64:x86_64 arm64:aarch64; do \
		export NFPM_PKG_VERSION=$(VERSION); \
		export NFPM_PKG_ARCH=$$(echo $$ARCHITECTURE | cut -d: -f1); \
		NFPM_CFG_FILE=".nfpm.yaml" \
		# The source directory appends a "_v1" to the architecture for arm64 \
		if [ "$$NFPM_PKG_ARCH" = "amd64" ]; then \
			NFPM_PKG_SRC_DIR=amd64_v1; \
		else \
			NFPM_PKG_SRC_DIR=$$NFPM_PKG_ARCH; \
		fi; \
		export NFPM_PKG_SRC=dist/$(BINARY_NAME)_linux_$$NFPM_PKG_SRC_DIR/$(BINARY_NAME); \
		FILENAME_ARCH=$$(echo $$ARCHITECTURE | cut -d: -f2); \
		FILENAME=$$FILENAME_ARCH/$(PACKAGE_NAME)-$(VERSION)-$$FILENAME_ARCH; \
		#envsubst < .nfpm.yaml >| .nfpm.yaml.tmp; \
		mkdir -p $(STAGING_DIR)/archlinux/$$FILENAME_ARCH; \
		mkdir -p $(STAGING_DIR)/rpm/$$FILENAME_ARCH; \
		nfpm -f $$NFPM_CFG_FILE package --packager rpm --target $(STAGING_DIR)/rpm/$$FILENAME.rpm; \
		nfpm -f $$NFPM_CFG_FILE package --packager archlinux --target $(STAGING_DIR)/archlinux/$$FILENAME.pkg.tar.zst; \
		# Debian packages use the original architecture name and a different directory structure \
		FILENAME_ARCH=$$NFPM_PKG_ARCH; \
		FILENAME=$(PACKAGE_NAME)_$(VERSION)-$(RELEASE_NUM)_$$FILENAME_ARCH; \
		mkdir -p $(STAGING_DIR)/deb/pool/main; \
		nfpm -f $$NFPM_CFG_FILE package --packager deb --target $(STAGING_DIR)/deb/pool/main/$$FILENAME.deb; \
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

.PHONY: repo-archlinux
repo-archlinux:
	repo-add --new --remove $(STAGING_DIR)/archlinux/x86_64/hello-world.db.tar.gz $(STAGING_DIR)/archlinux/x86_64/*.pkg.tar.zst
	repo-add --new --remove $(STAGING_DIR)/archlinux/aarch64/hello-world.db.tar.gz $(STAGING_DIR)/archlinux/aarch64/*.pkg.tar.zst

.PHONY: repo-deb
repo-deb:
	mkdir -p $(STAGING_DIR)/deb/dists/stable/main/binary-amd64
	mkdir -p $(STAGING_DIR)/deb/dists/stable/main/binary-arm64
	(cd $(STAGING_DIR)/deb/pool/main && dpkg-scanpackages --arch arm64 .) > $(STAGING_DIR)/deb/dists/stable/main/binary-arm64/Packages
	(cd $(STAGING_DIR)/deb/pool/main && dpkg-scanpackages --arch amd64 .) > $(STAGING_DIR)/deb/dists/stable/main/binary-amd64/Packages
	cat $(STAGING_DIR)/deb/dists/stable/main/binary-arm64/Packages | gzip -9c > $(STAGING_DIR)/deb/dists/stable/main/binary-arm64/Packages.gz
	cat $(STAGING_DIR)/deb/dists/stable/main/binary-amd64/Packages | gzip -9c > $(STAGING_DIR)/deb/dists/stable/main/binary-amd64/Packages.gz
	./tools/generate-deb-release.sh $(STAGING_DIR)/deb/pool/main > $(STAGING_DIR)/deb/dists/stable/Release

