#!/bin/bash

## This script downloads and generates a suitable ext4 image from existing cloud
## images. For simplicity it currently only downloads from Ubuntu images, but it
## should not be a big effort to adapt to other cloud images.

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )

source scripts/variables

function download() {
	echo "Downloading $2..."

	curl -s -o $1 $2
}

function download_if_not_present() {
	[ -f $1 ] || download $1 $2
}

function generate_image() {
	echo "Generating $IMAGE_ROOTFS..."

	truncate -s $IMAGE_SIZE $IMAGE_ROOTFS
	mkfs.ext4 $IMAGE_ROOTFS > /dev/null 2>&1

	local tmppath=/tmp/.$RANDOM-$RANDOM
	mkdir $tmppath
	sudo mount $IMAGE_ROOTFS -o loop $tmppath
	sudo tar -xf images/$UBUNTU_VERSION/download/$image_tar --directory $tmppath
	sudo umount $tmppath
	rmdir $tmppath
}

function extract_vmlinux() {
	echo "Extracting vmlinux to $KERNEL_IMAGE..."

	local extract_linux=/tmp/.$RANDOM-$RANDOM
	curl -s -o $extract_linux https://raw.githubusercontent.com/torvalds/linux/master/scripts/extract-vmlinux
	chmod +x $extract_linux
	$extract_linux images/$UBUNTU_VERSION/download/$kernel > $KERNEL_IMAGE
	rm $extract_linux
}


# Download components
mkdir -p images/$UBUNTU_VERSION/download

image_tar=$UBUNTU_VERSION-server-cloudimg-amd64-root.tar.xz
download_if_not_present \
	images/$UBUNTU_VERSION/download/$image_tar \
	https://cloud-images.ubuntu.com/$UBUNTU_VERSION/current/$image_tar

kernel=$UBUNTU_VERSION-server-cloudimg-amd64-vmlinuz-generic
download_if_not_present \
	images/$UBUNTU_VERSION/download/$kernel \
	https://cloud-images.ubuntu.com/$UBUNTU_VERSION/current/unpacked/$kernel

initrd=$UBUNTU_VERSION-server-cloudimg-amd64-initrd-generic
download_if_not_present \
	images/$UBUNTU_VERSION/$UBUNTU_VERSION.initrd \
	https://cloud-images.ubuntu.com/$UBUNTU_VERSION/current/unpacked/$initrd


# Generate image, kernel and link initrd
generate_image
extract_vmlinux
