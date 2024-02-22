#!/bin/bash
script_dir=$(cd $(dirname $0) && pwd)
source $script_dir/common.sh

REPO_URL="${REPO_BASE}/rpm/\$arch"
REPO_FILE="/etc/yum.repos.d/${PACKAGE_NAME}.repo"

docker run --rm rockylinux:9 /bin/bash -c "
    echo -e '[$PACKAGE_NAME]\nname=${PACKAGE_NAME} Repository\nbaseurl=$REPO_URL\nenabled=1\ngpgcheck=0' > $REPO_FILE;
    dnf install -y $PACKAGE_NAME;

    if ! command -v $EXECUTABLE_NAME &> /dev/null; then
        echo '$EXECUTABLE_NAME could not be installed.' >&2;
        exit 1;
    fi;

    PKG_VERSION=\$(dnf list installed $PACKAGE_NAME | grep -oP '\d+\.\d+\.\d+');
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
