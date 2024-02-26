#!/bin/bash
script_dir=$(cd $(dirname $0) && pwd)
source $script_dir/common.sh

docker run --rm debian:buster /bin/bash -c "
    apt-get update && apt-get install -y build-essential ca-certificates curl git;
    /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\";

    (echo; echo 'eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\"') >> /root/.bashrc;
    eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\";

    brew install joshbeard/hello-world/hello-world;

    if ! command -v $EXECUTABLE_NAME &> /dev/null; then
        echo '$EXECUTABLE_NAME could not be installed.' >&2;
        exit 1;
    fi;

    PKG_VERSION=\$(brew list $PACKAGE_NAME --versions | grep -oP '\K\d+\.\d+\.\d+');
    if [ \"\$PKG_VERSION\" != \"$EXPECTED_VERSION\" ]; then
        echo 'Version mismatch: expected $EXPECTED_VERSION, got '\"\$PKG_VERSION\"'.' >&2;
        exit 1;
    fi;

    INSTALLED_VERSION=\$($EXECUTABLE_NAME --version | grep -oP '\K\d+\.\d+\.\d+');
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
