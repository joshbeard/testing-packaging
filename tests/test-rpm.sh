#!/bin/bash

PACKAGE_NAME="hello-world"
REPO_URL="${REPO_BASE}/rpm/\$arch"
REPO_FILE="/etc/yum.repos.d/hello-world.repo"

# Start a Debian container and run tests inside it
docker run --rm -it rockylinux:9 /bin/bash -c "
    # Add your repository
    echo '=== Adding repository ===';
    echo -e '[hello-world]\nname=Hello World Repository\nbaseurl=$REPO_URL\nenabled=1\ngpgcheck=0' > $REPO_FILE;


    # Update and install your package
    echo '=== Installing package ===';
    dnf install -y $PACKAGE_NAME;

    # Verify installation
    echo '=== Verifying installation ===';
    if ! command -v $PACKAGE_NAME &> /dev/null; then
        echo '$PACKAGE_NAME could not be installed.' >&2;
        exit 1;
    fi;
    echo 'ok';

    # Check the version
    echo '=== Checking package version ===';
    PKG_VERSION=\$(dnf list installed $PACKAGE_NAME | grep -oP '\d+\.\d+\.\d+');
    if [ \"\$PKG_VERSION\" != \"$EXPECTED_VERSION\" ]; then
        echo 'Version mismatch: expected $EXPECTED_VERSION, got '\"\$PKG_VERSION\"'.' >&2;
        exit 1;
    fi;
    echo 'ok';

    echo '=== Checking executed version ===';
    INSTALLED_VERSION=\$($PACKAGE_NAME --version | grep -oP '\d+\.\d+\.\d+');
    if [ \"\$INSTALLED_VERSION\" != \"$EXPECTED_VERSION\" ]; then
        echo 'Version mismatch: expected $EXPECTED_VERSION, got '\"\$INSTALLED_VERSION\"'.' >&2;
        exit 1;
    fi;
    echo 'ok';

    # Insert additional functional tests here

    echo 'All tests passed!';
"

# Check if Docker command succeeded
if [ $? -eq 0 ]; then
    echo "Package $PACKAGE_NAME tests passed successfully."
else
    echo "Package $PACKAGE_NAME tests failed." >&2
    exit 1
fi


