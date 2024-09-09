set -o nounset
set -o errexit
set -o pipefail

USE_DOCKER=${USE_DOCKER:-"0"}

PKG_PATH=".meta/hack/pack"
PKG_NAME="mygaops.tar.gz"

PKG_VERSION="1.0.0"

