set -o nounset
set -o errexit
set -o pipefail

USE_DOCKER=${USE_DOCKER:-"0"}

PKG_PATH=".meta/hack/pack"

PKG_VERSION="1.1.4"
PKG_NAME="mygaops-${PKG_VERSION}.tar.gz"

REL_TAG="v${PKG_VERSION}"
REL_TITLE="Release v${PKG_VERSION}"
REL_NOTES="
## Bug Fixes
- Optimized start operation for improved initialization checks.
- Updated bashutils module to improve compatibility and performance.

## Improvements
- Enhanced init status check to prevent unnecessary reinitialization.
"
