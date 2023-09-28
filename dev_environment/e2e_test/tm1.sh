modprobe fou
ip fou add port 6080 gue
ip link add name gue1 type ipip remote 192.168.105.3 local 192.168.105.2 ttl 255 encap gue encap-sport 6080 encap-dport 6080 encap-csum encap-remcsum
ip link set dev gue1 up
