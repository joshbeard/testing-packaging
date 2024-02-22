#!/bin/bash

PACKAGE_NAME="hello-world"
REPO_URL="${REPO_BASE}/deb/"
REPO_FILE="/etc/apt/sources.list.d/hello_world.list"

docker run --rm debian:buster /bin/bash -c "
    apt-get update && apt-get install -y ca-certificates;
    echo 'deb [trusted=yes] $REPO_URL stable main' > $REPO_FILE;
    apt-get update && apt-get install -y $PACKAGE_NAME;

    if ! command -v $PACKAGE_NAME &> /dev/null; then
        echo '$PACKAGE_NAME could not be installed.' >&2;
        exit 1;
    fi;

    PKG_VERSION=\$(apt-cache policy $PACKAGE_NAME | grep -oP 'Installed: \K\d+\.\d+\.\d+');
    if [ \"\$PKG_VERSION\" != \"$EXPECTED_VERSION\" ]; then
        echo 'Version mismatch: expected $EXPECTED_VERSION, got '\"\$PKG_VERSION\"'.' >&2;
        exit 1;
    fi;

    INSTALLED_VERSION=\$($PACKAGE_NAME --version | grep -oP '\d+\.\d+\.\d+');
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
