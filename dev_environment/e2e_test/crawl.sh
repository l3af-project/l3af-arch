#!/usr/bin/bash

# Set the network interface and port variables
interface=$1
port=$2

# Run tcpdump and filter for packets on the given interface and port
tcpdump -i $interface port $port -c 5 > /dev/null

# Check if any packets were captured
if [ $? -eq 0 ]
then
    echo "Packets were captured on $interface port $port."
else
    echo "No packets were captured on $interface port $port."
fi
