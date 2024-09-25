set -o nounset
set -o errexit
set -o pipefail

USE_DOCKER=${USE_DOCKER:-"0"}

PKG_PATH=".meta/hack/pack"

PKG_VERSION="1.1.6"
PKG_NAME="mygaops-${PKG_VERSION}.tar.gz"

REL_TAG="v${PKG_VERSION}"
REL_TITLE="Release v${PKG_VERSION}"
REL_NOTES="
## Improvements
- Removed the \`BOOSTRAP\` environment variable to simplify the \`start\` and \`init\` logic.
- Optimized the \`check-safe-bootstrap\` function for simplicity, clarity, and independence from other nodes.
"
