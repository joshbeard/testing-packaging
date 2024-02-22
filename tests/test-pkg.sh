#!/bin/bash
script_dir=$(cd $(dirname $0) && pwd)
source $script_dir/common.sh

REPO_URL="${REPO_BASE}/pkg"
PACKAGE_URL="${REPO_URL}/${EXPECTED_VERSION}/${PACKAGE_NAME}_${EXPECTED_VERSION}_linux_amd64.tar.gz"

docker run --rm rockylinux:9 /bin/bash -c "
    curl -L $PACKAGE_URL -o /tmp/${PACKAGE_NAME}.tar.gz;
    tar -xzf /tmp/${PACKAGE_NAME}.tar.gz -C /tmp;
    mv /tmp/${EXECUTABLE_NAME} /usr/local/bin/${EXECUTABLE_NAME};
    chmod +x /usr/local/bin/${EXECUTABLE_NAME};

    if ! command -v $EXECUTABLE_NAME &> /dev/null; then
        echo '$EXECUTABLE_NAME could not be installed.' >&2;
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
