set -o nounset
set -o errexit
set -o pipefail

USE_DOCKER=${USE_DOCKER:-"0"}

PKG_PATH=".meta/hack/pack"

PKG_VERSION="1.0.4"
PKG_NAME="mygaops-${PKG_VERSION}.tar.gz"


REL_TAG="v${PKG_VERSION}"
REL_TITLE="Release v${PKG_VERSION}"
REL_NOTES="Optimize pkg_name rule."

