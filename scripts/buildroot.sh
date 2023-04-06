#!/bin/bash
set -euxo pipefail

sudo apt-get update && sudo apt-get install -yq tree

REPO_ROOT=$(realpath $(dirname "${BASH_SOURCE[0]}")/..)
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

root=$(pwd)/dist
work=$(pwd)/$(mktemp -d work-XXXX)
pushd $work || exit 1

function cleanup() {
  popd || true
  rm -r "$work" || true
}

trap cleanup EXIT

git clone https://github.com/buildroot/buildroot
pushd buildroot
git checkout 2023.02
popd || exit 1

make BR2_EXTERNAL=$REPO_ROOT -C buildroot default_defconfig
make BR2_EXTERNAL=$REPO_ROOT -C buildroot -j$(nproc)
cp $REPO_ROOT
tree $REPO_ROOT
tree buildroot
