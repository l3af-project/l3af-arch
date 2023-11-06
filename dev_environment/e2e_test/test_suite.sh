#!/bin/bash
# we are doing l3afd orchestration validation
RED='\033[0;31m'
NC='\033[0m' # No Color
GREEN='\033[0;32m'
close(){
  files=("err" "progids.txt" "tmp" "out.json" "names.txt" "tmpr","l3afd.log","l3afd.pid")
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
  exit 1
}
logsuc(){
  str=$1
  printf "${GREEN}${str}${NC}\n"
}
IP=`limactl shell bpfdev -- ip -brief address show lima0 | awk '{print $3}' | awk -F/ '{print $1}'`
validate() {
    touch progids.txt tmp out.json names.txt err
    curl -sS http://${IP}:7080/l3af/configs/v1/lima0 >out.json 2>&1
    echo >> out.json
    if cmp -s out.json $1.json; then
        curl -sS http://${IP}:8899/bpfs/lima0 | jq ".[].ProgID" >progids.txt 2>err
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
        tm_datapath_verification
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
        hey -n 200 -c 20 http://$IP:8080 > /dev/null
        for i in {1..1200}; do
          after_rl_drop_count=`curl -sS $IP:8898/metrics | grep rl_drop_count_map_0_scalar | awk '{print $NF}'`
          after_rl_recv_count=`curl -sS $IP:8898/metrics | grep rl_recv_count_map_0_max-rate | awk '{print $NF}'`
          if [[ $((after_rl_drop_count - before_rl_drop_count)) -ne 0 && $((after_rl_recv_count - before_rl_recv_count)) -ne 0 ]];then
            logsuc "ratelimiting updated the metrics maps"
            return
          fi
          sleep 1
        done
        logerr "ratelimiting not updating maps"
    fi 
}
cl_datapath_verification(){
    if grep -q "connection-limit" names.txt;then
        before_cl_recv_count=`curl -sS $IP:8898/metrics | grep cl_recv_count_map_0_scalar | awk '{print $NF}'`
        hey -n 200 -c 20 http://$IP:8080 > /dev/null
        for i in {1..1200}; do
          after_cl_recv_count=`curl -sS $IP:8898/metrics | grep cl_recv_count_map_0_scalar | awk '{print $NF}'`
          if [ $((after_cl_recv_count - before_cl_recv_count)) -ne 0 ];then
            logsuc "connection-limit updated the metrics maps"
            return
          fi
          sleep 1
        done
        logerr "connection-limit not updating the metrics maps"
    fi
}

ipfix_datapath_verification(){
    if grep -q "ipfix-flow-exporter" names.txt;then
            # Start tcpdump on lima0 and lo interfaces capturing traffic on ports 8080 and 49280 inside lima VM
      limactl shell bpfdev exec -- touch first first_err second second_err
      limactl shell bpfdev exec -- sudo tcpdump -i lima0 port 8080 -c 2 > first 2> first_err &
      limactl shell bpfdev exec -- sudo tcpdump -i lo port 49280 -c 2 > second 2> second_err &
      sleep 60
      hey -n 200 -c 20 http://${IP}:8080 > /dev/null
      for i in {1..2000}; do
      if [[ $(limactl shell bpfdev exec -- cat first | wc -l) -gt 0 ]] && [[ $(limactl shell bpfdev exec -- cat second | wc -l) -gt 0 ]]; then
        logsuc "ipfix-flow-exporter collecter is receiving packets"
        limactl shell bpfdev exec -- rm first second first_err second_err
        return
      fi
      sleep 1
      done
        limactl shell bpfdev exec -- rm first second first_err second_err
        logerr "ipfix-flow-exporter collecter not receiving packets"
    fi
}
tm_datapath_verification(){
  if grep -q "traffic-mirroring" names.txt;then
    limactl shell bpfdev exec -- touch tm_first tm_first_err
    limactl shell collector exec -- touch tm_second tm_second_err
    limactl shell bpfdev exec -- sudo tcpdump -i gue1 -c 2 > tm_first 2> tm_first_err &
    limactl shell collector exec -- sudo tcpdump -i lima0 -c 2 > tm_second 2> tm_second_err &
    sleep 60
    hey -n 200 -c 20 http://${IP}:8080 > /dev/null
    for i in {1..2000}; do
    if [[ $(limactl shell bpfdev exec -- cat tm_first | wc -l) -gt 0 ]] && [[ $(limactl shell collector exec -- cat tm_second | wc -l) -gt 0 ]]; then
      logsuc "traffic-mirroring mirroring the packets"
      limactl shell bpfdev exec -- rm tm_first tm_first_err
      limactl shell collector exec -- rm tm_second tm_second_err
      return
    fi
    sleep 1
    done
      limactl shell bpfdev exec -- cat tm_first_err
      limactl shell collector exec -- cat tm_second_err
      limactl shell bpfdev exec -- rm tm_first tm_first_err
      limactl shell collector exec -- rm tm_second tm_second_err
      logerr "traffic-mirroring not mirroring the packets"
  fi
}
api_runner() {
    name=$1
    file=$2
    num=$3
    touch tmpr
    #echo $name
    #echo $file
    #echo $num
    #echo $IP
    #curl -v http://${IP}:7080/l3af/configs/v1/lima0
    curl -sS -X POST http://${IP}:7080/l3af/configs/v1/${name} -H "Content-Type: application/json" -d "@${file}" > tmpr 2>&1
    if [ -s tmpr ]; then
        cat tmpr
        logerr "curl request to the ${name} API falied"
    fi
    validate $num $name
    close 
}


echo "with chaining"
api_runner "add" "payload.json" 1
api_runner "update" "upd_payload.json" 2
api_runner "add" "traffic_mirroring_payload.json" 3
api_runner "delete" "delete_payload.json" 4

l3afdID=$(limactl shell bpfdev exec -- pgrep l3afd)
limactl shell bpfdev exec -- sudo kill -9 "$l3afdID"
limactl shell bpfdev exec -- sudo rm -f /var/l3afd/l3af-config.json
limactl shell bpfdev exec -- sudo sed -i 's/bpf-chaining-enabled: true/bpf-chaining-enabled: false/' /root/l3af-arch/dev_environment/cfg/l3afd.cfg
limactl shell bpfdev exec -- bash -c "sudo /root/go/bin/l3afd --config /root/l3af-arch/dev_environment/cfg/l3afd.cfg > l3afd.log 2>&1" &
sleep 10
echo "without chaining"
api_runner "add" "payload-without-chaining.json" 5
api_runner "update" "upd-payload-without-chaining.json" 6
api_runner "delete" "delete-payload-without-chaining.json" 7

l3afdID=$(limactl shell bpfdev exec -- pgrep l3afd)
limactl shell bpfdev exec -- sudo kill -9 "$l3afdID"

logsuc "TEST COMPLETED"


