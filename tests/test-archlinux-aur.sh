#!/bin/bash

# Define package details
PACKAGE_NAME="hello-world"
REPO_URL="${REPO_BASE}/aur"

# Start an Arch Linux container and run tests inside it
docker run --rm archlinux /bin/bash -c "
    # Install dependencies
    pacman -Syu --noconfirm git base-devel

    # Create a user
    useradd -m -s /bin/bash archuser

    su - archuser -c '
        set -e
        set -x

        # Test installing from custom AUR repository.
        mkdir -p /tmp/aur
        cd /tmp/aur
        curl -L $REPO_URL/${PACKAGE_NAME}-bin.pkgbuild -o PKGBUILD
        curl -L $REPO_URL/${PACKAGE_NAME}-bin.srcinfo -o .SRCINFO

        makepkg -si --noconfirm
    '

    # Verify installation
    if ! command -v $PACKAGE_NAME &> /dev/null; then
        echo '$PACKAGE_NAME could not be installed.' >&2;
        exit 1
    fi

    # Check the version
    INSTALLED_VERSION=\$($PACKAGE_NAME --version | grep -oP '\d+\.\d+\.\d+')
    if [ \"\$INSTALLED_VERSION\" != \"$EXPECTED_VERSION\" ]; then
        echo 'Version mismatch: expected $EXPECTED_VERSION, got '\"\$INSTALLED_VERSION\"'.' >&2
        exit 1
    fi

    # Insert additional functional tests here

    echo 'All tests passed!'
"

# Check if Docker command succeeded
if [ $? -eq 0 ]; then
    echo "Package $PACKAGE_NAME tests passed successfully."
else
    echo "Package $PACKAGE_NAME tests failed." >&2
    exit 1
fi

