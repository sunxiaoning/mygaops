set -o nounset
set -o errexit
set -o pipefail

USE_DOCKER=${USE_DOCKER:-"0"}

PKG_PATH=".meta/hack/pack"

PKG_VERSION="1.1.3"
PKG_NAME="mygaops-${PKG_VERSION}.tar.gz"

REL_TAG="v${PKG_VERSION}"
REL_TITLE="Release v${PKG_VERSION}"
REL_NOTES="
## New Features
- **Improved** \`run.sh\`: optimized startup and initialization operations.
- **Improved** \`bashutils\` and \`rpmrepo\`: updated Git submodules.

## Bug Fixes
- Fixed an issue where \`make\` commands were not executed in sequence.
"
