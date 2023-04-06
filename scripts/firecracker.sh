#!/bin/bash
set -euxo pipefail

sudo apt-get update && sudo apt-get install -yq tree

FIRECRACKER_VERSION="v1.3.1"

root=$(pwd)/$(mktemp -d final-XXXX)
work=$(pwd)/$(mktemp -d work-XXXX)
pushd $work || exit 1

function cleanup() {
  popd
  rm -r "$work"
}

trap cleanup EXIT

mkdir -p $root/usr/local/bin/firecracker
wget "https://github.com/firecracker-microvm/firecracker/releases/download/${FIRECRACKER_VERSION}/firecracker-${FIRECRACKER_VERSION}-x86_64.tgz"
tar -xvf "firecracker-${FIRECRACKER_VERSION}-x86_64.tgz" --strip-components=1 -C $root/usr/local/bin/firecracker

tree $root

popd
rm -r "$WORKDIR"
