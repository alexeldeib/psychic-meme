#!/bin/sh

main() {
    devs=$(ls /sys/class/net | grep -v lo | grep -v sit)
    for dev in $devs; do
        echo $dev
        mac_ip=$(ip link show $dev | grep link/ether | tr -s ' ' | cut -d' ' -f3 | cut -d':' -f3-)
        echo "0x${mac_ip}"
        octets="$(echo "0x${mac_ip}" | sed "s/:/ 0x/g")"
        printf "%d.%d.%d.%d\n" $octets
        ip=$(printf "%d.%d.%d.%d" $octets)
        echo "$ip/30"
        ip addr add "$ip/30" dev $dev
        ip link set $dev up
    done
}
main
