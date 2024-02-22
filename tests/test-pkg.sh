#!/bin/bash

PACKAGE_NAME="hello-world"
REPO_URL="${REPO_BASE}/pkg"
PACKAGE_URL="${REPO_URL}/${EXPECTED_VERSION}/${PACKAGE_NAME}_${EXPECTED_VERSION}_linux_amd64.tar.gz"
GPG_PUBLIC_KEY_URL="${REPO_BASE}/gpg-pubkey.asc"

# Start a Debian container and run tests inside it
docker run --rm rockylinux:9 /bin/bash -c "
    curl -L $PACKAGE_URL -o /tmp/hello-world.tar.gz;
    tar -xzf /tmp/hello-world.tar.gz -C /tmp;
    mv /tmp/hello-world /usr/local/bin/hello-world;
    chmod +x /usr/local/bin/hello-world;

    if ! command -v $PACKAGE_NAME &> /dev/null; then
        echo '$PACKAGE_NAME could not be installed.' >&2;
        exit 1;
    fi;

    INSTALLED_VERSION=\$($PACKAGE_NAME --version | grep -oP '\d+\.\d+\.\d+');
    if [ \"\$INSTALLED_VERSION\" != \"$EXPECTED_VERSION\" ]; then
        echo 'Version mismatch: expected $EXPECTED_VERSION, got '\"\$INSTALLED_VERSION\"'.' >&2;
        exit 1;
    fi;

    curl -L $GPG_PUBLIC_KEY_URL -o /tmp/gpg-pubkey.gpg;
    echo '> Installing gnupg';
    dnf install -y gnupg;
    gpg --import /tmp/gpg-pubkey.gpg;
    gpg --verify /tmp/gpg-pubkey.gpg /tmp/hello-world.tar.gz;
    if [ \$? -ne 0 ]; then
        echo 'Signature verification failed.' >&2;
        exit 1;
    fi;
"

if [ $? -eq 0 ]; then
    echo "Package $PACKAGE_NAME tests passed successfully."
else
    echo "Package $PACKAGE_NAME tests failed." >&2
    exit 1
fi


