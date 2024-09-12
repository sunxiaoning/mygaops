#!/bin/bash
set -o nounset
set -o errexit
set -o pipefail

. .meta/hack/env.sh

EXCLUDES=(
  --exclude='*/README.md'
  --exclude='*/.meta'
  --exclude='*/.gh_token.txt'
  --exclude='*/.git'
  --exclude='*/.git*'
  --exclude='*/.vscode'
  --exclude='*/.dmypasswd.txt'
)

mkdir -p "${PKG_PATH}"

gtar "${EXCLUDES[@]}" -czvf "${PKG_PATH}/${PKG_NAME}" .

