#!/usr/bin/bash

set -eux

if [[ $EUID -ne 0 ]]; then
  echo " This script must be run as root"
  exit 1
fi
# we are doing l3afd orchestration validation
RED='\033[0;31m'
NC='\033[0m' # No Color
GREEN='\033[0;32m'
logerr(){
  str=$1
  printf "${RED} error: ${str} ${NC}\n"
}
logsuc(){
  str=$1
  printf "${GREEN}${str}${NC}\n"
}

validate() {
    touch progids.txt tmp out.json names.txt
    curl -sS http://localhost:7080/l3af/configs/v1/lima0 >out.json 2>&1
    if cmp -s out.json $1.json; then
        touch err
        curl -sS localhost:8899/bpfs/lima0 | jq ".[].ProgID" >progids.txt 2>err
        if [ -s err ]; then
            logerr "curl request to debug api failed"
            cat err
            rm err
            exit
        fi
        rm err
        declare idarray
        readarray -t idarray <progids.txt
        for str in ${idarray[@]}; do
            sudo bpftool prog show id $str >tmp

            if [ ! -s tmp ]; then
                logerr "Program with ProgID ${str} is not running"
                exit
            fi
            cat /dev/null >tmp
        done
        rm tmp progids.txt out.json names.txt
        logsuc "$2 API SUCCESS"
    else
        logerr "$2 API FAILED"
        diff -B -color $1.json out.json
        rm tmp progids.txt out.json
        exit
    fi
}

api_runner() {
    name=$1
    file=$2
    num=$3
    touch tmpr
    curl -sS -X POST http://localhost:7080/l3af/configs/v1/${name} -d @${file} >tmpr 2>&1
    if [ -s tmpr ]; then
        logerr "curl request to the ${name} API falied"
        cat tmpr
        rm tmpr
        exit
    fi
    validate $num $name
    rm tmpr
}



api_runner "add" "payload.json" 1
api_runner "update" "upd_payload.json" 2
api_runner "add" "traffic_mirroring_payload.json" 3
api_runner "delete" "delete_payload.json" 4
logsuc "TEST COMPLETED"


