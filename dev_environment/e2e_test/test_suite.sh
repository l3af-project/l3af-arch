#!/usr/bin/env bash
set -eux
export GOCOVERDIR="/root/coverdata/int"
# this script needs to run as root account, check it
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi
RED='\033[0;31m'
NC='\033[0m' # No Color
GREEN='\033[0;32m'

close() {
    files=("err" "progids.txt" "tmp" "output.json" "names.txt" "map_names.txt" "l3afd.log")
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
        for i in {1..100}; do
            traffic_gen $1
            after_rl_drop_count=$(curl -sS $IP:8898/metrics | grep rl_drop_count_map_0_scalar | awk '{print $NF}')
            if [[ $((after_rl_drop_count - before_rl_drop_count)) -ne 0 ]]; then
                logsuc "ratelimiting updated the metrics maps"
                return
            fi
            sleep 1
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
            sleep 1
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
    curl --max-time 120 -v -X POST http://${IP}:7080/l3af/configs/v1/${api_name} -H "Content-Type: application/json" -d "@${payload}"
    if [ $? -ne 0 ]; then
        logerr "curl request to the ${api_name} API falied"
        return
    fi
    validate $exp_output $api_name
    close
}

do_graceful_restart() {
    payload="/root/l3af-arch/dev_environment/e2e_test/restart.json"
    old_pid=$(cat /var/run/l3afd.pid)
    curl --max-time 120 -v -X PUT http://${IP}:7080/l3af/configs/v1/restart -H "Content-Type: application/json" -d "@${payload}"
    if [ $? -ne 0 ]; then
        logerr "curl request to the restart API falied"
        return 
    fi
    sleep 5
    if [ $(cat /var/run/l3afd.pid) -eq $old_pid ]; then
        logerr "curl request to the restart API falied"
        return 
    fi
    logsuc "Restart API is successful"
}
sleep 5
echo "with chaining"
api_runner "add" "add_payload.json" "exp_output_1.json"
sleep 2
do_graceful_restart
sleep 5
api_runner "update" "upd_payload.json" "exp_output_2.json"
sleep 2
api_runner "add" "add_tm_payload.json" "exp_output_3.json"
sleep 2
do_graceful_restart
sleep 5
api_runner "delete" "del_ipfix_payload.json" "exp_output_4.json"
sleep 2
api_runner "delete" "del_payload.json" "exp_output_nil.json"

l3afdID=$(pgrep l3afd)
kill -2 $l3afdID
rm -f /var/l3afd/l3af-config.json
sed -i --follow-symlinks 's/bpf-chaining-enabled: true/bpf-chaining-enabled: false/' $(readlink -f /usr/local/l3afd/latest/l3afd.cfg)

/usr/local/l3afd/latest/l3afd --config /usr/local/l3afd/latest/l3afd.cfg >l3afd.log 2>&1 &
sleep 5

echo "without chaining"
api_runner "add" "add_without_chaining_payload.json" "exp_output_5.json"
sleep 2
do_graceful_restart
sleep 5
api_runner "update" "upd_without_chaining_payload.json" "exp_output_6.json"
sleep 2
api_runner "delete" "del_without_chaining_payload.json" "exp_output_nil.json"
sleep 2
api_runner "add" "add_tm_payload.json" "exp_output_7.json"
sleep 2
api_runner "delete" "del_tm_payload.json" "exp_output_nil.json"

l3afdID=$(pgrep l3afd)
kill -2 $l3afdID


# TEST COVERAGE
TESTCOVERAGE_THRESHOLD=50
echo "Quality Gate: checking test coverage is above threshold ..."
echo "Threshold             : $TESTCOVERAGE_THRESHOLD %"

cd /root/l3afd
/usr/local/go/bin/go test -cover ./... -args -test.gocoverdir="/root/coverdata/unit"
/usr/local/go/bin/go tool covdata merge -i=/root/coverdata/int,/root/coverdata/unit -o /root/coverdata/combined
/usr/local/go/bin/go tool covdata textfmt -i=/root/coverdata/combined -o profile.txt
cov=`go tool cover -func=profile.txt | grep total | awk '{print $3}' | tr -d %`
rm -rf profile.txt
totalCoverage=$(echo "($cov+0.5)/1" | bc)
echo "Current test coverage : $totalCoverage %"

if [[ $totalCoverage -ge $TESTCOVERAGE_THRESHOLD ]]; then
	logsuc "OK"
else
	logerr "Current test coverage is below threshold. Please add more unit tests or adjust threshold to a lower value."
	logerr "Failed"
	close
	exit 1

fi
logsuc "TEST COMPLETED"
close
