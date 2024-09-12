set -o nounset
set -o errexit
set -o pipefail

USE_DOCKER=${USE_DOCKER:-"0"}

PKG_PATH=".meta/hack/pack"
PKG_NAME="mygaops.tar.gz"

PKG_VERSION="1.0.1"

REL_TAG="v${PKG_VERSION}"
REL_TITLE="Release v${PKG_VERSION}"
REL_NOTES="Update bashutils."

