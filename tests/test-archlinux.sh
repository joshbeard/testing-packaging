#!/bin/bash

PACKAGE_NAME="hello-world"
REPO_URL="${REPO_BASE}/archlinux/\$arch"

docker run --rm archlinux /bin/bash -c "
    echo -e '\n[hello-world]\nSigLevel = Optional TrustAll\nServer = $REPO_URL' >> /etc/pacman.conf
    pacman -Sy --noconfirm
    pacman -S --noconfirm $PACKAGE_NAME

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
