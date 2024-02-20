#!/usr/bin/env bash
set -a
export PACKAGE="hello-world"
export BINARY="hello-world"

export VERSION=$(git describe --tags --always --dirty)
export RELEASE=$(git rev-list --count HEAD)

DIST_DIR=dist
STAGING_DIR=${STAGING_DIR:-dist/staging}
S3_BUCKET=jbeard-test-pkgs

GORELEASER_VERSION=v1.23.0
NFPM_VERSION=v2.35.3

usage() {
    echo "Usage: $0 <command>"
    echo "Commands:"
    echo "  clean            - Remove build artifacts"
    echo "  snapshot         - Create a snapshot release"
    echo "  release          - Create a release"
    echo "  stage            - Stage release artifacts"
#    echo "  nfpm             - Create packages"
    echo "  repo <type>      - Create a repository for the specified package type"
    echo "  in_docker <type> - Create a repository for the specified package type in a Docker container"
    echo "  docker           - Run a Docker container with the current directory mounted"
    echo "  install_tools    - Install goreleaser and nfpm"
    echo
    echo "Repository types: archlinux, aur-custom, deb, rpm"
    exit 1
}

snapshot() {
    goreleaser --snapshot --skip=publish --clean #--skip-sign
    stage
    # _nfpm
}

release() {
    goreleaser release --clean
    stage
    # _nfpm
}

stage() {
    echo "=> Staging release artifacts"
    mkdir -p "${STAGING_DIR}/pkg/${VERSION}"
    mv $DIST_DIR/*.zip $DIST_DIR/*.tar.gz "${STAGING_DIR}/pkg/${VERSION}"/
    mv dist/checksums.txt "${STAGING_DIR}/pkg/${VERSION}/checksums.txt"
    mv dist/checksums.txt.sig "${STAGING_DIR}/pkg/${VERSION}/checksums.txt.sig"
    mkdir -p "${STAGING_DIR}/aur"
    mv -f dist/aur/* "${STAGING_DIR}/aur"
    _stage_repos
}

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
clean() {
    echo "=> Cleaning up"
    rm -rf dist/*
}

docker_shell() {
	docker run --rm -it -v ${PWD}:/go/src/github.com/${PACKAGE} \
		-w /go/src/github.com/${PACKAGE} golang:1.21 bash
}

install_tools() {
	go install github.com/goreleaser/goreleaser@${GORELEASER_VERSION}
	go install github.com/goreleaser/nfpm/v2/cmd/nfpm@${NFPM_VERSION}
}

purge_s3() {
    # Confirm
    echo "This will remove all files from the S3 bucket $S3_BUCKET"
    echo -n "Are you sure you want to continue? (yes/no): "
    read confirm
    if [ "$confirm" != "yes" ]; then
        echo "Aborting"
        exit 1
    fi

    aws s3 rm s3://$S3_BUCKET/ --recursive
}

# -----------------------------------------------------------------------------
# NFPM Package Build
# -----------------------------------------------------------------------------
_stage_repos() {
    echo "=> Creating packages with nfpm"
    for ARCHITECTURE in amd64:x86_64 arm64:aarch64; do
        echo "=> Creating package for $ARCHITECTURE"
        PKG_ARCH=$(echo $ARCHITECTURE | cut -d: -f1)
        FILENAME_ARCH=$(echo $ARCHITECTURE | cut -d: -f2)

        PKG_SRC_DIR=$PKG_ARCH
        if [ "$PKG_ARCH" = "amd64" ]; then
            PKG_SRC_DIR="amd64_v1"
        fi

        export PKG_SRC="dist/${BINARY}_linux_${PKG_SRC_DIR}/${BINARY}"
        FILENAME="${PACKAGE}_${VERSION}-${RELEASE}_${FILENAME_ARCH}"

        mkdir -p "${STAGING_DIR}/archlinux/${FILENAME_ARCH}"
        mkdir -p "${STAGING_DIR}/rpm/${FILENAME_ARCH}"

        export PKG_ARCH

        echo "=== Creating RPM"
        cp "${PKG_SRC}" "${STAGING_DIR}/rpm/${FILENAME_ARCH}/${FILENAME}.rpm"

        echo "=== Creating Arch Linux package"
        cp "${PKG_SRC}" "${STAGING_DIR}/archlinux/${FILENAME_ARCH}/${FILENAME}.pkg.tar.zst"

        # Debian packages use the original architecture name and a different
        # directory structure
        echo "=== Creating Debian package"
        PKG_ARCH=$(echo $ARCHITECTURE | cut -d: -f1)
		FILENAME="${PACKAGE}_${VERSION}-${RELEASE}_${PKG_ARCH}"
		mkdir -p "${STAGING_DIR}/deb/pool/main"
        cp "${PKG_SRC}" "${STAGING_DIR}/deb/pool/main/${FILENAME}.deb"
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
        aur-custom-docker)
            _repo_aur_custom_docker
            ;;
        aur-custom)
            _repo_aur_custom
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

in_docker() {
    shift
    repo_type=$1
    if [ -z "$repo_type" ]; then
        echo "No repository type specified"
        exit 1
    fi

    case $repo_type in
        rpm)
            _repo_rpm_docker_wrapper
            ;;
        aur-custom)
            _repo_aur_custom_docker_wrapper
            ;;
        archlinux)
            _repo_archlinux
            ;;
        deb)
            _repo_deb_docker_wrapper
            ;;
        *)
            echo "Unknown repository type: $repo_type"
            exit 1
            ;;
    esac
}


# -----------------------------------------------------------------------------
# RPM Repository Build
# -----------------------------------------------------------------------------
_repo_rpm_docker_wrapper() {
    docker run --rm -v ${PWD}:/work -v ${STAGING_DIR}:${STAGING_DIR} \
        -e STAGING_DIR=$STAGING_DIR \
        -e VERSION=$VERSION -e RELEASE=$RELEASE \
        -w /work -i rockylinux:9 \
        /bin/bash -c "dnf install -y git && /work/build.sh repo rpm"
}

_repo_rpm() {
    if ! command -v createrepo_c >>/dev/null 2>&1; then
        if ! command -v dnf >>/dev/null 2>&1; then
            echo "dnf not found"
            echo "create_repo_c is required to create the repository"
            echo "This expects to be ran on an EL-based system or container"
            exit 1
        fi
        dnf install -y createrepo_c
    fi

    if ! command -v git >>/dev/null 2>&1; then
        if ! command -v dnf >>/dev/null 2>&1; then
            echo "dnf not found"
            echo "git is required to create the repository"
            echo "This expects to be ran on an EL-based system or container"
            exit 1
        fi
        dnf install -y git
    fi

	createrepo_c --update "${STAGING_DIR}/rpm/x86_64"
	createrepo_c --update "${STAGING_DIR}/rpm/aarch64"
}

# -----------------------------------------------------------------------------
# Debian Repository Build
# -----------------------------------------------------------------------------
_repo_deb_docker_wrapper() {
    docker run --rm -v ${PWD}:/work -v ${STAGING_DIR}:${STAGING_DIR} \
        -e STAGING_DIR=$STAGING_DIR \
        -e VERSION=$VERSION -e RELEASE=$RELEASE \
        -w /work -i debian \
        /bin/bash -c "apt update && apt install -y git && /work/build.sh repo deb"
}

_repo_deb() {
    if ! command -v dpkg-scanpackages >>/dev/null 2>&1; then
        if ! command -v apt >>/dev/null 2>&1; then
            echo "apt not found"
            echo "dpkg-scanpackages is required to create the repository"
            echo "This expects to be ran on a Debian-based system or container"
            exit 1
        fi
        apt update
        apt install -y dpkg-dev
    fi

	AMD64_DIR="${STAGING_DIR}/deb/dists/stable/main/binary-amd64"
	ARM64_DIR="${STAGING_DIR}/deb/dists/stable/main/binary-arm64"
	mkdir -p "$AMD64_DIR" "$ARM64_DIR"

    echo "-> Creating amd64 package file"
	(cd "${STAGING_DIR}/deb" && dpkg-scanpackages --multiversion \
        --arch amd64 pool/) >| "$AMD64_DIR/Packages"

    echo "-> Creating arm64 package file"
	(cd "${STAGING_DIR}/deb" && dpkg-scanpackages --multiversion \
        --arch arm64 pool/) >| "$ARM64_DIR/Packages"

    echo "-> Creating amd64 package index files"
	cat "${STAGING_DIR}/deb/dists/stable/main/binary-amd64/Packages" | \
        gzip -9c > "${AMD64_DIR}/Packages.gz"

    echo "-> Creating arm64 package index files"
	cat "${STAGING_DIR}/deb/dists/stable/main/binary-arm64/Packages" | \
        gzip -9c > "${ARM64_DIR}/Packages.gz"

	./tools/generate-deb-release.sh "${STAGING_DIR}/deb/dists/stable" > \
        "${STAGING_DIR}/deb/dists/stable/Release"
}

# -----------------------------------------------------------------------------
# AUR Repository Build
# -----------------------------------------------------------------------------
# Runs 'repo-add' inside an 'archlinux' container to create a repository for
# the Arch Linux packages
_repo_aur_custom_docker_wrapper() {
    echo "=> Creating x86_64 AUR custom repository with Docker"
    docker run --rm -v ${PWD}:/work \
        -v ${STAGING_DIR}:${STAGING_DIR} \
        -w ${STAGING_DIR}/archlinux/x86_64 \
        -i archlinux:latest \
        /bin/bash -c "repo-add --new ${PACKAGE}.db.tar.gz ${PACKAGE}_${VERSION}_amd64.pkg.tar.zst"
}

_repo_aur_custom() {
	repo-add --new --remove "${STAGING_DIR}/archlinux/x86_64/${PACKAGE}.db.tar.gz" \
        "${STAGING_DIR}"/archlinux/x86_64/${PACKAGE}_${VERSION}_amd64.pkg.tar.zst
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
