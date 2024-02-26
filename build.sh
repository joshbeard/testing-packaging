#!/usr/bin/env bash
set -a
export PACKAGE="hello-world"
export BINARY="hello-world"

#export VERSION=$(git describe --tags --always --dirty)
export VERSION=$(git describe --tags --always --dirty)
export RELEASE=$(git rev-list --count HEAD)

# if dirty, replace "-dirty" with "-next"
if echo $VERSION | grep -q dirty; then
    export VERSION=$(echo $VERSION | sed 's/-dirty/-next/')
fi

DIST_DIR=dist
STAGING_DIR=${STAGING_DIR:-dist/staging}
S3_BUCKET=jbeard-test-pkgs

GORELEASER_VERSION=v1.23.0
NFPM_VERSION=v2.35.3

GPG_KEY_ID=${GPG_KEY_ID}
GPG_KEY_PASSPHRASE=${GPG_KEY_PASSPHRASE}

usage() {
    echo "Usage: $0 <command>"
    echo "Commands:"
    echo "  clean            - Remove build artifacts"
    echo "  snapshot         - Create a snapshot release"
    echo "  release          - Create a release"
    echo "  stage            - Stage release artifacts"
    echo "  repo <type>      - Create a repository for the specified package type"
    echo "  in_docker <type> - Create a repository for the specified package type in a Docker container"
    echo "  copy_latest      - Copy the latest versioned release to 'latest'"
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
    #mv $DIST_DIR/*.zip $DIST_DIR/*.tar.gz "${STAGING_DIR}/pkg/${VERSION}"/
    mv $DIST_DIR/*.tar.gz "${STAGING_DIR}/pkg/${VERSION}"/
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
# Generate install script
# -----------------------------------------------------------------------------
copy_latest() {
    echo "=> Copying latest release to 'latest'"
    mkdir -p "${STAGING_DIR}/pkg/latest"

    for f in $STAGING_DIR/pkg/${VERSION}/*; do
        new_file=$(basename $f | sed "s/${VERSION}/latest/")
        cp -f $f ${STAGING_DIR}/pkg/latest/$new_file

        # Replace the filename in the checksum file
        cp -f $STAGING_DIR/pkg/${VERSION}/checksums.txt ${STAGING_DIR}/pkg/latest/checksums.txt
        sed -i "s/${VERSION}/latest/" ${STAGING_DIR}/pkg/latest/checksums.txt

        # Generate a new signature for the latest checksum file
        echo "=> Signing the latest checksum file"
        [ -f "${STAGING_DIR}/pkg/latest/checksums.txt.sig" ] && rm -f "${STAGING_DIR}/pkg/latest/checksums.txt.sig"
        if [ -z "$GPG_KEY_PASSPHRASE" ]; then
            gpg --detach-sign --armor --output ${STAGING_DIR}/pkg/latest/checksums.txt.sig \
                ${STAGING_DIR}/pkg/latest/checksums.txt
        else
            echo "$GPG_KEY_PASSPHRASE" > key_pass.txt
            echo "A GPG_KEY_PASSPHRASE is set, using passphrase from key_pass.txt"

            gpg --detach-sign --armor --output ${STAGING_DIR}/pkg/latest/checksums.txt.sig \
                --pinentry-mode loopback --passphrase-file key_pass.txt \
                ${STAGING_DIR}/pkg/latest/checksums.txt

            rm -f key_pass.txt
        fi
    done
}

# -----------------------------------------------------------------------------
# Package Repositories
# -----------------------------------------------------------------------------
_stage_repos() {
    echo "=== Staging RPM packages ============================================"
    mkdir -p "${STAGING_DIR}/rpm/x86_64"
    mkdir -p "${STAGING_DIR}/rpm/aarch64"
    cp "${DIST_DIR}/${PACKAGE}_${VERSION}_linux_amd64.rpm" \
        "${STAGING_DIR}/rpm/x86_64/${PACKAGE}_${VERSION}_x86_64.rpm"
    cp "${DIST_DIR}/${PACKAGE}_${VERSION}_linux_arm64.rpm" \
        "${STAGING_DIR}/rpm/aarch64/${PACKAGE}_${VERSION}_aarch64.rpm"


    echo "=== Staging Arch Linux packages ====================================="
    mkdir -p "${STAGING_DIR}/archlinux/x86_64"
    cp "${DIST_DIR}/${PACKAGE}_${VERSION}_linux_amd64.pkg.tar.zst" \
        "${STAGING_DIR}/archlinux/x86_64/${PACKAGE}_${VERSION}_x86_64.pkg.tar.zst"

    echo "=== Staging Debian packages ========================================="
    mkdir -p "${STAGING_DIR}/deb/pool/main"
    cp "${DIST_DIR}/${PACKAGE}_${VERSION}_linux_amd64.deb" \
        "${STAGING_DIR}/deb/pool/main/${PACKAGE}_${VERSION}_amd64.deb"
    cp "${DIST_DIR}/${PACKAGE}_${VERSION}_linux_arm64.deb" \
        "${STAGING_DIR}/deb/pool/main/${PACKAGE}_${VERSION}_arm64.deb"
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
        apk)
            _repo_apk
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
        apk)
            _repo_apk_docker_wrapper
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
        -e GPG_KEY_ID=$GPG_KEY_ID -e GPG_KEY_PASSPHRASE=$GPG_KEY_PASSPHRASE \
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

    echo "=> Signing the Release file"
    _repo_deb_gpgsign
}

_repo_deb_gpgsign() {
    if [ -z "$GPG_KEY_ID" ]; then
        echo "GPG_KEY_ID is not set"
        echo "Set the GPG_KEY_ID environment variable to the GPG key ID to use"
        exit 1
    fi

    if ! command -v gpg >>/dev/null 2>&1; then
        echo "gpg not found"
        echo "gpg is required to sign the Release file"
        exit 1
    fi

    cd "${STAGING_DIR}/deb/dists/stable"
    echo "=> Signing the Release file with GPG key $GPG_KEY_ID"
    if [ -z "$GPG_KEY_PASSPHRASE" ]; then
        set +x
        gpg --list-secret-keys
        gpg --list-keys

        [ -f "Release.gpg" ] && rm -f "Release.gpg"
        gpg --armor --detach-sign --batch --output Release.gpg -u "$GPG_KEY_ID" Release

        [ -f "InRelease" ] && rm -f "InRelease"
        gpg --clearsign --digest-algo SHA256 --batch --local-user "$GPG_KEY_ID" --output InRelease Release
        set -x
    else
        echo "$GPG_KEY_PASSPHRASE" > key_pass.txt
        echo "A GPG_KEY_PASSPHRASE is set, using passphrase from key_pass.txt"
        set +x

        [ -f "Release.gpg" ] && rm -f "Release.gpg"
        gpg --armor --detach-sign --output Release.gpg --batch -u "$GPG_KEY_ID" \
            --pinentry-mode loopback --passphrase-file key_pass.txt Release

        [ -f "InRelease" ] && rm -f "InRelease"
        gpg --clearsign --digest-algo SHA256 --batch --local-user "$GPG_KEY_ID" \
            --pinentry-mode loopback --passphrase-file key_pass.txt \
            --output InRelease Release
        rm -f key_pass.txt
        set -x
    fi
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
        /bin/bash -c "repo-add --new ${PACKAGE}.db.tar.gz ${PACKAGE}_${VERSION}_x86_64.pkg.tar.zst"
}

_repo_aur_custom() {
	repo-add --new --remove "${STAGING_DIR}/archlinux/x86_64/${PACKAGE}.db.tar.gz" \
        "${STAGING_DIR}"/archlinux/x86_64/${PACKAGE}_${VERSION}_x86_64.pkg.tar.zst
}

# -----------------------------------------------------------------------------
# APK Repository Build
# -----------------------------------------------------------------------------
_repo_apk_docker_wrapper() {
    docker run --rm -v ${PWD}:/work \
        -v ${STAGING_DIR}:${STAGING_DIR} \
        -w /work \
        -e GPG_KEY_ID=$GPG_KEY_ID -e GPG_KEY_PASSPHRASE=$GPG_KEY_PASSPHRASE \
        -e STAGING_DIR=$STAGING_DIR \
        -i alpine:latest \
        /bin/ash -c "
            apk update && apk add abuild bash git gpg;
            ./build.sh repo apk;
        "
}

_repo_apk() {
    mkdir -p "${STAGING_DIR}/apk/x86_64"
    cp "${DIST_DIR}/${PACKAGE}_${VERSION}_linux_amd64.apk" \
        "${STAGING_DIR}/apk/x86_64/${PACKAGE}_${VERSION}_x86_64.apk"

    mkdir -p "${STAGING_DIR}/apk/aarch64"
    cp "${DIST_DIR}/${PACKAGE}_${VERSION}_linux_arm64.apk" \
        "${STAGING_DIR}/apk/aarch64/${PACKAGE}_${VERSION}_aarch64.apk"

    # Generate the APK index
    apk index -vU \
        -o "${STAGING_DIR}/apk/x86_64/APKINDEX.tar.gz" \
        "${STAGING_DIR}/apk/x86_64/*.apk"

    apk index -vU \
        -o "${STAGING_DIR}/apk/aarch64/APKINDEX.tar.gz" \
        "${STAGING_DIR}/apk/aarch64/*.apk"

    # Sign the APK index
    gpg --export-secret-keys --armor $GPG_KEY_ID > /tmp/private.key
    
    abuild-sign -k /tmp/private.key \
        "${STAGING_DIR}/apk/x86_64/APKINDEX.tar.gz"
    abuild-sign -k /tmp/private.key \
        "${STAGING_DIR}/apk/aarch64/APKINDEX.tar.gz"

    chown -R 1099:1099 "${STAGING_DIR}/apk"

    rm -f /tmp/private.key
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

