#!/bin/bash
set -euxo pipefail

sudo apt-get update && sudo apt-get install -yq tree libelf-dev

REPO_ROOT=$(realpath $(dirname "${BASH_SOURCE[0]}")/..)

mkdir -p /tmp/buildroot || true

root=$(pwd)/dist
work=/tmp/buildroot
pushd $work || exit 1

function cleanup() {
  popd || true
  rm -r "$work" || true
}

# trap cleanup EXIT

git clone https://github.com/buildroot/buildroot || true
pushd buildroot
git checkout 2023.02
popd || exit 1
popd || exit 1

mkdir -p $REPO_ROOT/output
make -C $work/buildroot O=$REPO_ROOT/output BR2_EXTERNAL=$REPO_ROOT default_defconfig
make -C $work/buildroot O=$REPO_ROOT/output -j$(nproc) &> make.log
pid=$?

if [ "$pid" != "0" ]; then
  echo "failed to build kernel!"
  tail -n 50 make.log
fi

tree $REPO_ROOT/output/images
