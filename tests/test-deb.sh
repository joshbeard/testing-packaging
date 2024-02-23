#!/bin/bash
script_dir=$(cd $(dirname $0) && pwd)
source $script_dir/common.sh

REPO_URL="${REPO_BASE}/deb/"
REPO_FILE="/etc/apt/sources.list.d/${PACKAGE_NAME}.list"

docker run --rm debian:buster /bin/bash -c "
    apt-get update && apt-get install -y ca-certificates wget gpg;

    echo '> Downloading gpg key'
    wget -qO- https://${REPO_BASE}/gpg-pubkey.asc | gpg --dearmor > ${PACKAGE_NAME}-repo-keyring.gpg;
    mkdir -p /etc/apt/keyrings;
    echo '> Installing gpg key'
    cat ${PACKAGE_NAME}-repo-keyring.gpg > /etc/apt/keyrings/${PACKAGE_NAME}-repo-keyring.gpg;

    echo '> Adding repository'
    echo \"deb [arch=amd64 signed-by=/etc/apt/keyrings/${PACKAGE_NAME}-repo-keyring.gpg] ${REPO_URL} stable main\" > /etc/apt/sources.list.d/${PACKAGE_NAME}.list;
    echo '> Installing package'
    apt-get update && apt-get install -y $PACKAGE_NAME;

    if ! command -v $EXECUTABLE_NAME &> /dev/null; then
        echo '$EXECUTABLE_NAME could not be installed.' >&2;
        exit 1;
    fi;

    PKG_VERSION=\$(apt-cache policy $PACKAGE_NAME | grep -oP 'Installed: \K\d+\.\d+\.\d+');
    if [ \"\$PKG_VERSION\" != \"$EXPECTED_VERSION\" ]; then
        echo 'Version mismatch: expected $EXPECTED_VERSION, got '\"\$PKG_VERSION\"'.' >&2;
        exit 1;
    fi;

    INSTALLED_VERSION=\$($EXECUTABLE_NAME --version | grep -oP '\d+\.\d+\.\d+');
    if [ \"\$INSTALLED_VERSION\" != \"$EXPECTED_VERSION\" ]; then
        echo 'Version mismatch: expected $EXPECTED_VERSION, got '\"\$INSTALLED_VERSION\"'.' >&2;
        exit 1;
    fi;
"

if [ $? -eq 0 ]; then
    echo "Package $PACKAGE_NAME tests passed successfully."
else
    echo "Package $PACKAGE_NAME tests failed." >&2
    exit 1
fi
