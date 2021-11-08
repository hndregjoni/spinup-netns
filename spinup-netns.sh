#!/bin/bash

# Heavily inspired by:
# https://gist.github.com/dpino/6c0dca1742093346461e11aa8f608a99

### Forwarding
FORWARDING=`cat /proc/sys/net/ipv4/ip_forward`

if [ "$FORWARDING" = "0" ]; then
    echo Forwarding not active.
    echo Execute '> /proc/sys/net/ipv4/ip_forward'
    exit
fi
###

### root
if [[ $EUID -ne 0 ]]; then
    echo "You must be root to run this script"
    exit 1
fi
###

IFACE=""
CNT=1

function usage {
    echo "spinup-netns.sh"
    echo -e "\t-h: Usage"
    echo -e "\t-i: Network interface"
    echo -e "\t-n: Specify a new index"
    exit
}

while getopts "hi:n:" arg; do
    case $arg in
        i)
            IFACE=$OPTARG
            ;;
        n)
            CNT=$OPTARG
            ;;
        h|*)
            usage
            ;;
    esac
done

# We place these here since they depend on $CNT
NS=ephemeral$CNT
VETH=veth$CNT
VPEER=vpeer$CNT
IP=10.200.$CNT.addr

if ip netns | grep -w -q "$NS"; then
    echo "Namespace $NS already exists!"
    echo "Consider specifying index with -n"
    exit;
fi

# Interface error
if [ -z "$IFACE" ]; then
    echo Please specify interface
    exit
fi

### IPs
function ip_for {
    # kind of overkill
    echo ${IP/addr/$1} 
}

VETH_ADDR=`ip_for 1`
VPEER_ADDR=`ip_for 2`
###

function iptables_up {
    # Setup itables
    iptables -A FORWARD -i $IFACE -o $VETH -j ACCEPT
    iptables -A FORWARD -o $IFACE -i $VETH -j ACCEPT

    iptables -t nat -A POSTROUTING -s $VPEER_ADDR/24 -o $IFACE -j MASQUERADE
}

function iptables_down {
    # Do the opposite
    iptables -D FORWARD -i $IFACE -o $VETH -j ACCEPT
    iptables -D FORWARD -o $IFACE -i $VETH -j ACCEPT

    iptables -t nat -D POSTROUTING -s $VPEER_ADDR/24 -o $IFACE -j MASQUERADE
}

### CLEANUP
function cleanup {
    # Delete veth pair
    ip link del $VETH
    # Delete namespace
    ip netns del $NS

    # Undo iptables
    iptables_down
}

trap cleanup EXIT
###

# Create namespace (delete if exists) and start loopback
ip netns del $NS &>/dev/null
ip netns add $NS
ip netns exec $NS ip link set dev lo up

# Create interface peer
ip link add $VETH type veth peer name $VPEER
# Set namespace for VPEER
ip link set $VPEER netns $NS

# Set ip on global namespace, and set the interface up
ip addr add $VETH_ADDR/24 dev $VETH
ip link set $VETH up

# Setup for $VPEER
ip netns exec $NS ip add add $VPEER_ADDR/24 dev $VPEER
ip netns exec $NS ip link set $VPEER up
ip netns exec $NS ip route add default via $VETH_ADDR

# iptables stuff
iptables_up

ip netns exec ${NS} /bin/bash --rcfile <(echo "PS1=\"${NS}> \"")
