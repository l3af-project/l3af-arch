ip netns add bpf
ip link add ibpf type veth peer name ibpfbr
ip link set ibpf netns bpf
ip addr add 192.168.15.80/24 dev ibpfbr
ip -n bpf addr add 192.168.15.1/24 dev ibpf
ip -n bpf link set ibpf up
ip -n bpf link set lo up
ip link set ibpfbr up
modprobe fou
ip fou add port 6080 gue
ip fou add port 6081 gue
ip link add name gue1 type ipip remote 127.0.0.1 local 192.168.15.80  ttl 255 encap gue encap-sport 6080 encap-dport 6081 encap-csum encap-remcsum
ip link add name gue2 type ipip remote 192.168.15.80 local 127.0.0.1  ttl 255 encap gue encap-sport 6081 encap-dport 6080 encap-csum encap-remcsum
ip link set dev gue1 up
ip link set dev gue2 up
