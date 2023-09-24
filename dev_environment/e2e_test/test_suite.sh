#!/bin/bash
# we are doing l3afd orchestration validation
RED='\033[0;31m'
NC='\033[0m' # No Color
GREEN='\033[0;32m'
close(){
  files=("err" "progids.txt" "tmp" "out.json" "names.txt" "tmpr")
  for d in ${files[@]}; do
    if test -f $d;then
      rm $d
    fi
  done
}
logerr(){
  str=$1
  close 
  printf "${RED} error: ${str} ${NC}\n"
  exit
}
logsuc(){
  str=$1
  printf "${GREEN}${str}${NC}\n"
}
IP=`limactl shell bpfdev -- ip -brief address show lima0 | awk '{print $3}' | awk -F/ '{print $1}'`
validate() {
    touch progids.txt tmp out.json names.txt err
    fl="curl -sS http://${IP}:7080/l3af/configs/v1/lima0"
    $fl >out.json 2>&1
    if cmp -s out.json $1.json; then
        fl="curl -sS http://${IP}/bpfs/lima0"
        $fl | jq ".[].ProgID" >progids.txt 2>err
        if [ -s err ]; then
            cat err
            logerr "curl request to debug api failed"
        fi
        curl -sS http://$IP:8899/bpfs/lima0 | jq ".[].Program.name" >names.txt 2>err
        if [ -s err ]; then
            cat err
            logerr "curl request to debug api failed"
        fi
	idarray=()
	while IFS= read -r line; do
	idarray+=("$line")
	done < "progids.txt"

        for str in ${idarray[@]}; do
            limactl shell bpfdev exec -- sudo bpftool prog show id $str >tmp 

            if [ ! -s tmp ]; then
                logerr "Program with ProgID ${str} is not running"
            fi
            cat /dev/null >tmp
        done
        rl_datapath_verification
        cl_datapath_verification
        ipfix_datapath_verification
        close
        logsuc "$2 API SUCCESS"
    else
        diff $1.json out.json
        logerr "$2 API FAILED"
    fi
}

rl_datapath_verification(){
    if grep -q "ratelimiting" names.txt;then
        before_rl_drop_count=`curl -sS $IP:8898/metrics | grep rl_drop_count_map_0_scalar | awk '{print $NF}'`
        before_rl_recv_count=`curl -sS $IP:8898/metrics | grep rl_recv_count_map_0_max-rate | awk '{print $NF}'`
        hey -n 10 -c 10 http://$IP:8080 > /dev/null
        sleep 5
        after_rl_drop_count=`curl -sS $IP:8898/metrics | grep rl_drop_count_map_0_scalar | awk '{print $NF}'`
        after_rl_recv_count=`curl -sS $IP:8898/metrics | grep rl_recv_count_map_0_max-rate | awk '{print $NF}'`

        if [ $(expr $after_rl_drop_count - $before_rl_drop_count) -ne 0 ];then
            logsuc "rl_drop_count changed"
          else
            logerr "rl_dropcount is not good"
        fi
        if [ $(expr $after_rl_recv_count - $before_rl_recv_count) -ne 0 ];then
            logsuc "rl_recv_count changed"
          else
            logerr "rl_recv_count is not good"
        fi 
    fi 
}
cl_datapath_verification(){
    if grep -q "connection-limit" names.txt;then
        before_cl_recv_count=`curl -sS $IP:8898/metrics | grep cl_recv_count_map_0_scalar | awk '{print $NF}'`
        hey -n 10 -c 10 http://$IP:8080 > /dev/null
	sleep 10
        after_cl_recv_count=`curl -sS $IP:8898/metrics | grep cl_recv_count_map_0_scalar | awk '{print $NF}'`

        if [ $(expr $after_cl_recv_count - $before_cl_recv_count) -eq 2 ];then
            logsuc "cl_recv_count is good"
        else
		logerr "cl_recv_count is not good"
	fi
    fi
}

ipfix_datapath_verification(){
    if grep -q "ipfix-flow-exporter" names.txt;then
            # Start tcpdump on lima0 and lo interfaces capturing traffic on ports 8080 and 49280 inside lima VM
      limactl shell bpfdev exec -- sudo timeout 100 tcpdump -i lima0 port 8080 > first 2>&1 &
      limactl shell bpfdev exec -- sudo timeout 100 tcpdump -i lo port 49280 > second 2>&1 &

      sleep 20
      # Send 10 HTTP requests using hey command from host
      fl="http://${IP}:8080"
      hey -n 10 -c 10 $fl > /dev/null

      # Wait for tcpdump to capture all packets
      sleep 80
      limactl shell bpfdev exec -- sed '1,2d' first  > /dev/null
      limactl shell bpfdev exec -- sed '1,2d' second  > /dev/null
      # Check if packets were captured on both interfaces inside lima VM
      if [[ $(limactl shell bpfdev exec -- cat first | wc -l) -gt 0 ]] && [[ $(limactl shell bpfdev exec -- cat second | wc -l) -gt 0 ]]; then
        logsuc "ipfix-flow-exporter collecter is receiving packets"
        limactl shell bpfdev exec -- rm first second
      else
        limactl shell bpfdev exec -- rm first second
        logerr "ipfix-flow-exporter collecter not receiving packets"
      fi
    fi
}
api_runner() {
    name=$1
    file=$2
    num=$3
    touch tmpr
    url="curl -sS X POST http://${IP}:7080/l3af/configs/v1/${name}"
    $url -d "@${file}" > tmpr 2>&1 
    if [ -s tmpr ]; then
        cat tmpr
        logerr "curl request to the ${name} API falied"
    fi
    validate $num $name
    close 
}



api_runner "add" "payload.json" 1
api_runner "update" "upd_payload.json" 2
api_runner "add" "traffic_mirroring_payload.json" 3
api_runner "delete" "delete_payload.json" 4
logsuc "TEST COMPLETED"

