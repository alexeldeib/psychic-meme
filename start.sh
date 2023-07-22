#!/bin/sh
set -x

TAP_DEV="tap0"
# TAP_IP="172.16.0.1"
# MASK_SHORT="/30"

# Setup network interface
# ip link del "$TAP_DEV" 2> /dev/null || true
# ip tuntap add dev "$TAP_DEV" mode tap
# ip addr add "${TAP_IP}${MASK_SHORT}" dev "$TAP_DEV"
# ip link set dev "$TAP_DEV" up

# # Enable ip forwarding
# sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"

# # Set up microVM internet access
# iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE || true
# iptables -D FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT \
# || true
# iptables -D FORWARD -i tap0 -o eth0 -j ACCEPT || true
# iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
# iptables -I FORWARD 1 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
# iptables -I FORWARD 1 -i tap0 -o eth0 -j ACCEPT
LOGFILE="./firecracker.log"
API_SOCKET="./firecracker.socket"

# cleanup() {
#     ret=$?
#     rm -f "${API_SOCKET}"
#     rm -f "${LOGFILE}"
#     exit $?
# }

# trap cleanup EXIT INT TERM

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
INITRD="/rootfs.cpio"
KERNEL_BOOT_ARGS="console=ttyS0 reboot=k panic=1 pci=off"

# Set boot source
curl -X PUT --unix-socket "${API_SOCKET}" \
    --data "{
        \"kernel_image_path\": \"${KERNEL}\",
        \"boot_args\": \"${KERNEL_BOOT_ARGS}\",
        \"initrd_path\": \"${INITRD}\"
    }" \
    "http://localhost/boot-source"

curl -X PUT --unix-socket "${API_SOCKET}" \
    --data "{
        \"drive_id\": \"user\",
        \"path_on_host\": \"${ROOTFS}\",
        \"is_root_device\": false,
        \"is_read_only\": true
    }" \
    "http://localhost/drives/user"

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

sleep 0.015s

wait $pid
echo $?
cat $LOGFILE
