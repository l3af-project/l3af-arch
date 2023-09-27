#!/usr/bin/bash

touch first.pcap second.pcap
sudo tcpdump -i lima0 port 8080 -c 5 -w first.pcap &
sudo tcpdump -i lo port 49280 -c 5 -w second.pcap &

