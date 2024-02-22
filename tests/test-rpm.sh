#!/bin/bash

PACKAGE_NAME="hello-world"
REPO_URL="${REPO_BASE}/rpm/\$arch"
REPO_FILE="/etc/yum.repos.d/hello-world.repo"

docker run --rm rockylinux:9 /bin/bash -c "
    echo -e '[hello-world]\nname=Hello World Repository\nbaseurl=$REPO_URL\nenabled=1\ngpgcheck=0' > $REPO_FILE;
    dnf install -y $PACKAGE_NAME;

    if ! command -v $PACKAGE_NAME &> /dev/null; then
        echo '$PACKAGE_NAME could not be installed.' >&2;
        exit 1;
    fi;

    PKG_VERSION=\$(dnf list installed $PACKAGE_NAME | grep -oP '\d+\.\d+\.\d+');
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
