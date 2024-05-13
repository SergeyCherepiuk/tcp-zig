#!/bin/bash

# Check if all arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <device_name> <ip_address>/<network_mask>"
    echo "Example: $0 tun0 192.168.10.1/24"
    exit 1
fi

# Declare variables
device_name="$1"
ip_address="$2"

# Build the program
zig build

# Attach network administration capability to compiled executable
sudo setcap CAP_NET_ADMIN=ep ./zig-out/bin/main

# Run an executable in the background
./zig-out/bin/main $device_name &

# Write the process id into $pid variable
pid=$!

# Assign IPv4 address to the TUN interface
sudo ip addr add $ip_address dev $device_name

# Bring the TUN link up
sudo ip link set up dev $device_name

# Clean up function for graceful shutdown
cleanup() {
	kill $pid
	exit
}

# Run "cleanup" function when SIGINT or SIGTERM is received
trap cleanup SIGINT SIGTERM

# Wait for the program to finish
wait $pid
