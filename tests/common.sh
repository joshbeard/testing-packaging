#!/bin/bash
script_dir=$(cd $(dirname $0) && pwd)

# This script should only be included, not executed
if [ "$0" = "$BASH_SOURCE" ]; then
    echo "This script should only be included, not executed"
    exit 1
fi

export DIST_DIR="${script_dir}/../dist"

export PACKAGE_NAME="hello-world"
export EXECUTABLE_NAME="hello-world"

export REPO_BASE="https://pkgs.home.jbeard.dev"
export GPG_PUBLIC_KEY_URL="${REPO_BASE}/gpg-pubkey.asc"

export SOURCE_VERSION=$(git describe --tags --always --dirty | sed 's/dirty/next/g')
export EXPECTED_VERSION=$(echo "$SOURCE_VERSION" | sed -E 's/([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
export RELEASE="1"

export OS="linux"
export FILENAME_BASE="${PACKAGE_NAME}_${SOURCE_VERSION}_${OS}_amd64"

export TERM=xterm-256color

green=`tput setaf 2`
red=`tput setaf 1`
reset=`tput sgr0`
