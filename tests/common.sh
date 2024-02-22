#!/bin/bash
# This script should only be included, not executed
if [ "$0" = "$BASH_SOURCE" ]; then
    echo "This script should only be included, not executed"
    exit 1
fi

export PACKAGE_NAME="hello-world"
export EXECUTABLE_NAME="hello-world"
export REPO_BASE="https://pkgs.home.jbeard.dev"
export EXPECTED_VERSION=$(git describe --tags --always --dirty | sed -E 's/([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
export RELEASE="1"
export GPG_PUBLIC_KEY_URL="${REPO_BASE}/gpg-pubkey.asc"
export TERM=xterm-256color

green=`tput setaf 2`
red=`tput setaf 1`
reset=`tput sgr0`
