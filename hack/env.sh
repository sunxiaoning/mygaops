set -o nounset
set -o errexit
set -o pipefail

USE_DOCKER=${USE_DOCKER:-"0"}

PKG_PATH="hack/pack"

PKG_VERSION="1.1.13"
PKG_NAME="mygaops-${PKG_VERSION}.tar.gz"

REL_TAG="v${PKG_VERSION}"
REL_TITLE="Release v${PKG_VERSION}"
REL_NOTES="
## Improvements
- Optimized the \`mygaops\` operation process for improved efficiency and clarity.
- Refined the \`install\`, \`run\`, and \`uninstall\` logic to streamline operations.
- Updated the \`bashutils\` and \`rpmrepo\` submodule versions for enhanced functionality.
"
