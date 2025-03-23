#!/bin/sh
# This script installs Kuzco on Linux.
# It detects the current operating system architecture and installs the appropriate version of Kuzco.

KUZCO_BASE_URL=${KUZCO_BASE_URL:-"kuzco.xyz"} # Used for switching between prod and dev (kuzco.cool or kuzco.xyz)
BUCKET_URL=${BUCKET_URL:-"cfs.$KUZCO_BASE_URL"}
WEB_URL=${WEB_URL:-"https://$KUZCO_BASE_URL"}
API_URL=${API_URL:-"https://relay.$KUZCO_BASE_URL"}
NATS_URL=${NATS_URL:-"wss://nats-tls.$KUZCO_BASE_URL"}
NATS_LOGS_SERVER_URL=${NATS_LOGS_SERVER_URL:-"wss://nats-logs.$KUZCO_BASE_URL"}

set -eu

status() { echo ">>> $*" >&1; }
error() { echo "ERROR $*" >&2; exit 1; }
warning() { echo "WARNING: $*"; }

DEBUG_MODE=${DEBUG_MODE:-false}

TEMP_DIR=$(mktemp -d)
cleanup() { rm -rf $TEMP_DIR; }
trap cleanup EXIT

available() { command -v $1 >/dev/null; }
require() {
    local MISSING=''
    for TOOL in $*; do
        if ! available $TOOL; then
            MISSING="$MISSING $TOOL"
        fi
    done

    echo $MISSING
}

[ "$(uname -s)" = "Linux" ] || [ "$(uname -s)" = "Darwin" ] || error 'This script is intended to run on Linux or macOS only.'

ARCH=$(uname -m)
case "$ARCH" in 
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) 
        if [ "$(uname)" = "Darwin" ]; then
            ARCH="darwin-aarch64"
        else
            ARCH="arm64"
        fi
        ;;
    *) error "Unsupported architecture: $ARCH" ;;  
esac

if [ "$DEBUG_MODE" = "true" ]; then
    echo "ARCH: $ARCH" >&2
fi

UNAME=$(uname -s)
if [ "$DEBUG_MODE" = "true" ]; then
    echo "UNAME: $UNAME" >&2
fi

KERN=$(uname -r)
case "$KERN" in
    *icrosoft*WSL2 | *icrosoft*wsl2) ;;
    *icrosoft) error "Microsoft WSL1 is not currently supported. Please upgrade to WSL2 with 'wsl --set-version <distro> 2'" ;;
    *) ;;
esac

SUDO=
if [ "$(id -u)" -ne 0 ]; then
    # Running as root, no need for sudo
    if ! available sudo; then
        error "This script requires superuser permissions. Please re-run as root."
    fi

    SUDO="sudo"
fi

NEEDS=$(require curl awk grep sed tee xargs)
if [ -n "$NEEDS" ]; then
    status "ERROR: The following tools are required but missing:"
    for NEED in $NEEDS; do
        echo "  - $NEED"
    done
    exit 1
fi

# Download versions.json for versioning (production kuzco.xyz)
download_versions_json() {
    # include timestamp to cache-bust
    local TIMESTAMP=$(date +%s)
    local VERSIONS_URL="https://$BUCKET_URL/cli-versions.json?t=$TIMESTAMP"
    curl --fail --show-error --location --progress-bar -o $TEMP_DIR/versions.json "$VERSIONS_URL"
}

status "Getting versions.json..."
download_versions_json

# Extract cli-latest version information
CLI_VERSION=${CLI_VERSION:-$(awk -F'"' '/cli-latest/ {print $4}' $TEMP_DIR/versions.json)}
echo "CLI_VERSION: $CLI_VERSION"

if [ "$DEBUG_MODE" = "true" ]; then
    echo "ARCH: $ARCH" >&2
fi

DID_DOWNLOAD_KUZCO=false

status "Downloading kuzco..."
if [ "$UNAME" = "Linux" ]; then
    KUZCO_BINARY_URL="${BUCKET_URL}/cli/release/${ARCH}/kuzco-linux-${ARCH}-${CLI_VERSION}"
    KUZCO_RUNTIME_URL="${BUCKET_URL}/cli/runtime/${ARCH}/kuzco-runtime-linux-${ARCH}-${CLI_VERSION}"
    LIB_URL="${BUCKET_URL}/cli/runtime/${ARCH}/kuzco-linux-${ARCH}-lib-${CLI_VERSION}.tar.gz"

    if [ "$DEBUG_MODE" = "true" ]; then
        status "Detected Linux"
        status "KUZCO_BINARY_URL: $KUZCO_BINARY_URL"
        status "KUZCO_RUNTIME_URL: $KUZCO_RUNTIME_URL"
        status "LIB_URL: $LIB_URL"
    fi

    curl --fail --show-error --location --progress-bar -o $TEMP_DIR/kuzco $KUZCO_BINARY_URL
    curl --fail --show-error --location --progress-bar -o $TEMP_DIR/kuzco-runtime $KUZCO_RUNTIME_URL
    curl --fail --show-error --location --progress-bar -o $TEMP_DIR/lib.tar.gz $LIB_URL

    if [ "$DEBUG_MODE" = "true" ]; then
        status "Downloaded kuzco, kuzco-runtime, and lib.tar.gz"
    fi

    DID_DOWNLOAD_KUZCO=true
fi

if [ "$UNAME" = "Darwin" ] && [ "$ARCH" = "darwin-aarch64" ]; then
    KUZCO_BINARY_URL="${BUCKET_URL}/cli/release/macos/kuzco-darwin-aarch64-$CLI_VERSION"
    KUZCO_RUNTIME_URL="${BUCKET_URL}/cli/runtime/macos/kuzco-runtime-darwin-aarch64-$CLI_VERSION"

    if [ "$DEBUG_MODE" = "true" ]; then
        status "Detected Darwin"
        status "KUZCO_BINARY_URL: $KUZCO_BINARY_URL"
        status "KUZCO_RUNTIME_URL: $KUZCO_RUNTIME_URL"
    fi

    curl --fail --show-error --location --progress-bar -o $TEMP_DIR/kuzco $KUZCO_BINARY_URL
    curl --fail --show-error --location --progress-bar -o $TEMP_DIR/kuzco-runtime $KUZCO_RUNTIME_URL

    if [ "$DEBUG_MODE" = "true" ]; then
        status "Downloaded kuzco and kuzco-runtime"
    fi

    DID_DOWNLOAD_KUZCO=true
fi

if [ "$DID_DOWNLOAD_KUZCO" = "false" ]; then
    error "Failed to download kuzco -- unsupported architecture and platform combination: $ARCH + $UNAME"
fi

for BINDIR in /usr/local/bin /usr/bin /bin; do
    echo $PATH | grep -q $BINDIR && break || continue
done

status "Installing kuzco to $BINDIR..."
$SUDO install -o0 -g0 -m755 -d $BINDIR
$SUDO install -o0 -g0 -m755 $TEMP_DIR/kuzco $BINDIR/kuzco
$SUDO install -o0 -g0 -m755 $TEMP_DIR/kuzco-runtime $BINDIR/kuzco-runtime

if [ "$(uname -s)" = "Linux" ]; then
    status "Extracting lib files..."
    $SUDO tar -xzf $TEMP_DIR/lib.tar.gz -C $BINDIR
fi

install_success() { 
    status 'Installation complete! Use "kuzco worker start --worker <worker-id> --code <registration-code>" to start your worker.'
}
trap install_success EXIT
