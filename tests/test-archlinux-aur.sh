#!/bin/bash

# Define package details
PACKAGE_NAME="hello-world"
REPO_URL="${REPO_BASE}/aur"

docker run --rm archlinux /bin/bash -c "
    pacman -Syu --noconfirm git base-devel
    useradd -m -s /bin/bash archuser
    echo \"archuser ALL=(ALL) NOPASSWD: ALL\" | sudo EDITOR=\"tee -a\" visudo

    su - archuser -c '
        set -e
        set -x

        mkdir -p /tmp/aur
        cd /tmp/aur
        curl -L $REPO_URL/${PACKAGE_NAME}-bin.pkgbuild -o PKGBUILD
        curl -L $REPO_URL/${PACKAGE_NAME}-bin.srcinfo -o .SRCINFO

        # Replace the 'https://get.jbeard.dev' URL with REPO_BASE
        sed -i \"s|https://get.jbeard.dev|$REPO_BASE|g\" PKGBUILD
        sed -i \"s|https://get.jbeard.dev|$REPO_BASE|g\" .SRCINFO

        makepkg -si --noconfirm
    '

    if ! command -v $PACKAGE_NAME &> /dev/null; then
        echo '$PACKAGE_NAME could not be installed.' >&2;
        exit 1
    fi

    INSTALLED_VERSION=\$($PACKAGE_NAME --version | grep -oP '\d+\.\d+\.\d+')
    if [ \"\$INSTALLED_VERSION\" != \"$EXPECTED_VERSION\" ]; then
        echo 'Version mismatch: expected $EXPECTED_VERSION, got '\"\$INSTALLED_VERSION\"'.' >&2
        exit 1
    fi
"

if [ $? -eq 0 ]; then
    echo "Package $PACKAGE_NAME tests passed successfully."
else
    echo "Package $PACKAGE_NAME tests failed." >&2
    exit 1
fi
