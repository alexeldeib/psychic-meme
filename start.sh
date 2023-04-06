#!/bin/sh
set -x

LOGFILE="./firecracker.log"
API_SOCKET="./firecracker.socket"

/usr/local/bin/firecracker/firecracker-v1.3.1-x86_64 --api-sock ${API_SOCKET} &
pid=$!

# Create log file
touch $LOGFILE

# Set log file
curl -X PUT --unix-socket "${API_SOCKET}" \
    --data "{
        \"log_path\": \"${LOGFILE}\",
        \"level\": \"Debug\",
        \"show_level\": true,
        \"show_log_origin\": true
    }" \
    "http://localhost/logger"

ARCH=$(uname -m)
KERNEL="/vmlinux"
KERNEL_BOOT_ARGS="console=ttyS0 reboot=k panic=1 pci=off"


# Set boot source
curl -X PUT --unix-socket "${API_SOCKET}" \
    --data "{
        \"kernel_image_path\": \"${KERNEL}\",
        \"boot_args\": \"${KERNEL_BOOT_ARGS}\"
    }" \
    "http://localhost/boot-source"

# ROOTFS="/rootfs.ext4"
# curl -X PUT --unix-socket "${API_SOCKET}" \
#     --data "{
#         \"drive_id\": \"rootfs\",
#         \"path_on_host\": \"${ROOTFS}\",
#         \"is_root_device\": true,
#         \"is_read_only\": false
#     }" \
#     "http://localhost/drives/rootfs"

# The IP address of a guest is derived from its MAC address with
# `fcnet-setup.sh`, this has been pre-configured in the guest rootfs. It is
# important that `TAP_IP` and `FC_MAC` match this.
FC_MAC="06:00:AC:10:00:02"

# Set network interface
curl -X PUT --unix-socket "${API_SOCKET}" \
    --data "{
        \"iface_id\": \"net1\",
        \"guest_mac\": \"$FC_MAC\",
        \"host_dev_name\": \"$TAP_DEV\"
    }" \
    "http://localhost/network-interfaces/net1"

# API requests are handled asynchronously, it is important the configuration is
# set, before `InstanceStart`.
sleep 0.015s

# Start microVM
curl -X PUT --unix-socket "${API_SOCKET}" \
    --data "{
        \"action_type\": \"InstanceStart\"
    }" \
    "http://localhost/actions"

wait $pid
