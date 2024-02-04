#!/bin/sh
set -a
export PACKAGE="hello-world"
export BINARY="hello-world"

export VERSION=$(git describe --tags --always --dirty)
export RELEASE=$(git rev-list --count HEAD)

DIST_DIR=dist
STAGING_DIR=dist/staging

GORELEASER_VERSION=v1.23.0
NFPM_VERSION=v2.35.3

usage() {
    echo "Usage: $0 <command>"
    echo "Commands:"
    echo "  clean - Remove build artifacts"
    echo "  snapshot - Create a snapshot release"
    echo "  release - Create a release"
    echo "  stage - Stage release artifacts"
    echo "  nfpm - Create packages"
    echo "  repo <type> - Create a repository for the specified package type"
    echo "  docker - Run a Docker container with the current directory mounted"
    echo "  install_tools - Install goreleaser and nfpm"
    exit 1
}

snapshot() {
    goreleaser --snapshot --skip-publish --clean --skip-sign
    stage
    _nfpm
}

release() {
    goreleaser release --clean
    stage
    _nfpm
}

stage() {
    echo "=> Staging release artifacts"
    mkdir -p "${STAGING_DIR}/pkg/${VERSION}"
    mv $DIST_DIR/*.zip $DIST_DIR/*.tar.gz "${STAGING_DIR}/pkg/${VERSION}"/
    mv dist/checksums.txt "${STAGING_DIR}/pkg/${VERSION}/checksums.txt"
    mv dist/aur "${STAGING_DIR}"
}

clean() {
    echo "=> Cleaning up"
    rm -rf dist/*
}

docker() {
	docker run --rm -it -v ${PWD}:/go/src/github.com/${PACKAGE} \
		-w /go/src/github.com/${PACKAGE} golang:1.21 bash
}

install_tools() {
	go install github.com/goreleaser/goreleaser@${GORELEASER_VERSION}
	go install github.com/goreleaser/nfpm/v2/cmd/nfpm@${NFPM_VERSION}
}

_nfpm() {
    echo "=> Creating packages with nfpm"
    NFPM_CFG_FILE=".nfpm.yaml"
    for ARCHITECTURE in amd64:x86_64 arm64:aarch64; do
        echo "=> Creating package for $ARCHITECTURE"
        PKG_ARCH=$(echo $ARCHITECTURE | cut -d: -f1)
        FILENAME_ARCH=$(echo $ARCHITECTURE | cut -d: -f2)

        if [ "$PKG_ARCH" = "amd64" ]; then
            PKG_ARCH="amd64_v1"
        fi

        PKG_SRC_DIR=$PKG_ARCH
        export PKG_SRC="dist/${BINARY}_linux_${PKG_SRC_DIR}/${BINARY}"
        FILENAME="${PACKAGE}_${VERSION}-${RELEASE}_${FILENAME_ARCH}"

        mkdir -p "${STAGING_DIR}/archlinux/${FILENAME_ARCH}"
        mkdir -p "${STAGING_DIR}/rpm/${FILENAME_ARCH}"

        export PKG_ARCH

		nfpm -f "$NFPM_CFG_FILE" package --packager rpm \
            --target "${STAGING_DIR}/rpm/${FILENAME_ARCH}/${FILENAME}.rpm"

		nfpm -f "$NFPM_CFG_FILE" package --packager archlinux \
            --target "${STAGING_DIR}/archlinux/${FILENAME_ARCH}/${FILENAME}.rpm"

        # Debian packages use the original architecture name and a different
        # directory structure
        PKG_ARCH=$(echo $ARCHITECTURE | cut -d: -f1)
		FILENAME="${PACKAGE}_${VERSION}-${RELEASE}_${PKG_ARCH}"
		mkdir -p "${STAGING_DIR}/deb/pool/main"
		nfpm -f "$NFPM_CFG_FILE" package --packager deb \
            --target "${STAGING_DIR}/deb/pool/main/${FILENAME}.deb"
    done
}

repo() {
    shift
    repo_type=$1
    if [ -z "$repo_type" ]; then
        echo "No repository type specified"
        exit 1
    fi

    case $repo_type in
        rpm)
            _repo_rpm
            ;;
        archlinux)
            _repo_archlinux
            ;;
        deb)
            _repo_deb
            ;;
        *)
            echo "Unknown repository type: $repo_type"
            exit 1
            ;;
    esac
}

_repo_rpm() {
	createrepo_c --update "${STAGING_DIR}/rpm/x86_64"
	createrepo_c --update "${STAGING_DIR}/rpm/aarch64"
}

_repo_archlinux() {
	repo-add --new --remove "${STAGING_DIR}/archlinux/x86_64/${PACKAGE}.db.tar.gz" \
        "${STAGING_DIR}"/archlinux/x86_64/*.pkg.tar.zst

	repo-add --new --remove "${STAGING_DIR}/archlinux/aarch64/${PACKAGE}.db.tar.gz" \
        "${STAGING_DIR}"/archlinux/aarch64/*.pkg.tar.zst
}

_repo_deb() {
	AMD64_DIR="${STAGING_DIR}/deb/dists/stable/main/binary-amd64"
	ARM64_DIR="${STAGING_DIR}/deb/dists/stable/main/binary-arm64"
	mkdir -p "$AMD64_DIR" "$ARM64_DIR"

    echo "-> Creating amd64 package file"
	(cd "${STAGING_DIR}/deb/pool/main" && ls && dpkg-scanpackages \
        --arch amd64 "$PWD" /dev/null) >| "$AMD64_DIR/Packages"

    echo "-> Creating arm64 package file"
	(cd "${STAGING_DIR}/deb/pool/main" && dpkg-scanpackages \
        --arch arm64 . /dev/null) >| "$ARM64_DIR/Packages"

    echo "-> Creating amd64 package index files"
	cat "${STAGING_DIR}/deb/dists/stable/main/binary-amd64/Packages" | \
        gzip -9c > "${AMD64_DIR}/Packages.gz"

    echo "-> Creating arm64 package index files"
	cat "${STAGING_DIR}/deb/dists/stable/main/binary-arm64/Packages" | \
        gzip -9c > "${ARM64_DIR}/Packages.gz"

	./tools/generate-deb-release.sh "${STAGING_DIR}/deb/pool/main" > \
        "${STAGING_DIR}/deb/dists/stable/Release"
}

# Execute the function that matches the first argument
# e.g. `build.sh clean` runs the `clean` function
if [ $# -lt 1 ]; then
    usage
    exit 0
fi

# Check for a function with the same name as the first argument
if [ "$(type -t $1)" = "function" ]; then
    $1 $@
else
    echo "Unknown command: $1"
    exit 1
fi

#$1 $@

# if [ "$(type -t $1)" = "function" ]; then
#     $1
# else
#     echo "Unknown command: $1"
#     exit 1
# fi
