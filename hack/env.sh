set -o nounset
set -o errexit
set -o pipefail

USE_DOCKER=${USE_DOCKER:-"0"}

PKG_PATH="hack/pack"

PKG_VERSION="1.1.11"
PKG_NAME="mygaops-${PKG_VERSION}.tar.gz"

REL_TAG="v${PKG_VERSION}"
REL_TITLE="Release v${PKG_VERSION}"
REL_NOTES="
## Improvements
- Removed the \`make\` dependency in MySQL Galera Cluster operation.
- Added \`mygaops.sh\` as an interface for operating Galera Cluster.
"
