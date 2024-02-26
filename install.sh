#!/bin/bash
VERSION="${VERSION:-latest}"
# Base URL for downloading packages
BASE_URL="https://get.jbeard.dev/pkg/${VERSION}"
# Target installation directory
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

# Detect OS and Arch
OS=$(uname | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64)
        ARCH="aarch64"
        ;;
    arm64)
        ARCH="aarch64" # Translate arm64 to aarch64 if necessary
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Construct download URL
TAR_FILE="hello-world_${VERSION}_${OS}_${ARCH}.tar.gz"
DOWNLOAD_URL="${BASE_URL}/${TAR_FILE}"

# Checksum file URL
CHECKSUM_URL="${BASE_URL}/checksums.txt"

# Download artifact
echo "Downloading ${TAR_FILE}..."
curl -sSLO "${DOWNLOAD_URL}"

# Download checksums
echo "Downloading checksums..."
curl -sSLO "${CHECKSUM_URL}"

# Verify checksum
echo "Verifying checksum..."
CHECKSUM=$(grep "${TAR_FILE}" checksums.txt | awk '{print $1}')
if [ -z "${CHECKSUM}" ]; then
    echo "Failed to find checksum for ${TAR_FILE} in checksums.txt"
    exit 1
fi

echo "${CHECKSUM}  ${TAR_FILE}" | sha256sum -c -
if [ $? -ne 0 ]; then
    echo "Checksum verification failed!"
    exit 1
else
    echo "Checksum verified successfully."
fi

# Extract and install
mkdir -p "${INSTALL_DIR}"
tar -xzf "${TAR_FILE}" -C "${INSTALL_DIR}"
if [ $? -ne 0 ]; then
    echo "Failed to extract ${TAR_FILE}"
    exit 1
else
    echo "Installed successfully to ${INSTALL_DIR}"
fi

# Cleanup
rm -f "${TAR_FILE}" "checksums.txt"

# Add ${INSTALL_DIR} to PATH if not already present
if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
    echo "Consider adding ${INSTALL_DIR} to your PATH"
fi
