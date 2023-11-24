#!/usr/bin/env bash
set -eu
# this script needs to run as root account, check it
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi
RED='\033[0;31m'
NC='\033[0m' # No Color
GREEN='\033[0;32m'

close() {
    files=("err" "progids.txt" "tmp" "output.json" "names.txt" "tmpr" "map_names.txt" "l3afd.log" "l3afd.pid")
    for d in ${files[@]}; do
        if test -f $d; then
            rm $d
        fi
    done
}

logerr() {
    str=$1
    close
    printf "${RED} error: ${str} ${NC}\n"
    exit 1
}

logsuc() {
    str=$1
    printf "${GREEN}${str}${NC}\n"
}

IP=192.168.15.80
# traffic_gen provide traffic for give direction testing
traffic_gen() {
    if [ $1 == "ingress" ]; then
        ip netns exec bpf bash -c "hey -n 2000 -c 200 http://192.168.15.80:8080" >/dev/null
    elif [ $1 == "egress" ]; then
        hey -n 2000 -c 200 http://192.168.15.1:8080 >/dev/null
    else
        echo "Provide valid direction"
        exit 1
    fi
}

validate() {
    exp_output=$1
    api_name=$2
    touch progids.txt tmp output.json names.txt err
    curl -sS http://${IP}:7080/l3af/configs/v1/ibpfbr >output.json 2>&1
    echo >>output.json
    if cmp -s output.json /root/l3af-arch/dev_environment/e2e_test/$exp_output; then
        curl -sS http://${IP}:8899/bpfs/ibpfbr | jq ".[].ProgID" >progids.txt 2>err
        if [ -s err ]; then
            cat err
            logerr "curl request to debug api failed"
        fi
        curl -sS http://$IP:8899/bpfs/ibpfbr | jq ".[].Program.name" >names.txt 2>err
        if [ -s err ]; then
            cat err
            logerr "curl request to debug api failed"
        fi
        curl -sS http://$IP:8899/bpfs/ibpfbr | jq ".[].Program.map_name" >map_names.txt 2>err
        if [ -s err ]; then
            cat err
            log err "curl request to debug api failed"
        fi
        idarray=()
        while IFS= read -r line; do
            idarray+=("$line")
        done <"progids.txt"
        for str in ${idarray[@]}; do
            bpftool prog show id $str >tmp
            if [ ! -s tmp ]; then
                logerr "Program with ProgID ${str} is not running"
            fi
            cat /dev/null >tmp
        done
        cl_datapath_verification "ingress"
        rl_datapath_verification "ingress"
        tm_datapath_verification "ingress"
        tm_datapath_verification "egress"
        ipfix_datapath_verification "ingress"
        ipfix_datapath_verification "egress"
        logsuc "$api_name API SUCCESS"
        printf "\n"
    else
        diff $exp_output output.json
        logerr "$api_name API FAILED"
        printf "\n"
    fi
}

rl_datapath_verification() {
    if grep -q "ratelimiting" names.txt; then
        before_rl_drop_count=$(curl -sS $IP:8898/metrics | grep rl_drop_count_map_0_scalar | awk '{print $NF}')
        before_rl_recv_count=$(curl -sS $IP:8898/metrics | grep rl_recv_count_map_0_max-rate | awk '{print $NF}')
        for i in {1..100}; do
            traffic_gen $1
            after_rl_drop_count=$(curl -sS $IP:8898/metrics | grep rl_drop_count_map_0_scalar | awk '{print $NF}')
            after_rl_recv_count=$(curl -sS $IP:8898/metrics | grep rl_recv_count_map_0_max-rate | awk '{print $NF}')
            if [[ $((after_rl_drop_count - before_rl_drop_count)) -ne 0 && $((after_rl_recv_count - before_rl_recv_count)) -ne 0 ]]; then
                logsuc "ratelimiting updated the metrics maps"
                return
            fi
        done
        logerr "ratelimiting not updating maps"
    fi
}

cl_datapath_verification() {
    if grep -q "connection-limit" names.txt; then
        before_cl_recv_count=$(curl -sS $IP:8898/metrics | grep cl_recv_count_map_0_scalar | awk '{print $NF}')
        for i in {1..100}; do
            traffic_gen $1
            after_cl_recv_count=$(curl -sS $IP:8898/metrics | grep cl_recv_count_map_0_scalar | awk '{print $NF}')
            if [ $((after_cl_recv_count - before_cl_recv_count)) -ne 0 ]; then
                logsuc "connection-limit updated the metrics maps"
                return
            fi
        done
        logerr "connection-limit not updating the metrics maps"
    fi
}

ipfix_datapath_verification() {
    mapname="ipfix_$1_jmp_table"
    if grep -q "ipfix-flow-exporter" names.txt && grep -q $mapname map_names.txt; then
        touch first first_err second second_err
        tcpdump -i ibpfbr port 8080 -c 2 >first 2>first_err &
        tcpdump -i lo port 49280 -c 2 >second 2>second_err &
        sleep 4
        traffic_gen $1
        for i in {1..100}; do
            if [[ $(cat first | wc -l) -gt 0 ]] && [[ $(cat second | wc -l) -gt 0 ]]; then
                logsuc "ipfix-flow-exporter ($1) collector is receiving packets"
                rm first second first_err second_err
                return
            fi
            sleep 1
        done
        rm first second first_err second_err
        logerr "ipfix-flow-exporter ($1) collector not receiving packets"
    fi
}

tm_datapath_verification() {
    mapname="mirroring_$1_jmp_table"
    if grep -q "traffic-mirroring" names.txt && grep -q $mapname map_names.txt; then
        touch tm_first tm_first_err
        touch tm_second tm_second_err
        tcpdump -i gue1 -c 2 >tm_first 2>tm_first_err &
        tcpdump -i lo udp and port 6081 -c 2 >tm_second 2>tm_second_err &
        sleep 4
        traffic_gen $1
        for i in {1..100}; do
            if [[ $(cat tm_first | wc -l) -gt 0 ]] && [[ $(cat tm_second | wc -l) -gt 0 ]]; then
                logsuc "traffic-mirroring ($1) mirroring the packets"
                rm tm_first tm_first_err
                rm tm_second tm_second_err
                return
            fi
            sleep 1
        done
        cat tm_first_err
        cat tm_second_err
        rm tm_first tm_first_err
        rm tm_second tm_second_err
        logerr "traffic-mirroring ($1) not mirroring the packets"
    fi
}

api_runner() {
    api_name=$1
    payload="/root/l3af-arch/dev_environment/e2e_test/$2"
    exp_output=$3
    touch tmpr
    curl -sS -X POST http://${IP}:7080/l3af/configs/v1/${api_name} -H "Content-Type: application/json" -d "@${payload}" >tmpr 2>&1
    if [ -s tmpr ]; then
        cat tmpr
        logerr "curl request to the ${api_name} API falied"
    fi
    validate $exp_output $api_name
    close
}

echo "with chaining"
api_runner "add" "add_payload.json" "exp_output_1.json"
api_runner "update" "upd_payload.json" "exp_output_2.json"
api_runner "add" "add_tm_payload.json" "exp_output_3.json"
api_runner "delete" "del_ipfix_payload.json" "exp_output_4.json"
api_runner "delete" "del_payload.json" "exp_output_nil.json"

l3afdID=$(pgrep l3afd)
kill -9 $l3afdID
rm -f /var/l3afd/l3af-config.json
sed -i 's/bpf-chaining-enabled: true/bpf-chaining-enabled: false/' /root/l3af-arch/dev_environment/cfg/l3afd.cfg
/root/go/bin/l3afd --config /root/l3af-arch/dev_environment/cfg/l3afd.cfg >l3afd.log 2>&1 &
sleep 10

echo "without chaining"
api_runner "add" "add_without_chaining_payload.json" "exp_output_5.json"
api_runner "update" "upd_without_chaining_payload.json" "exp_output_6.json"
api_runner "delete" "del_without_chaining_payload.json" "exp_output_nil.json"
api_runner "add" "add_tm_payload.json" "exp_output_7.json"
api_runner "delete" "del_tm_payload.json" "exp_output_nil.json"

l3afdID=$(pgrep l3afd)
kill -9 $l3afdID
logsuc "TEST COMPLETED"
close
