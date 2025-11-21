#!/usr/bin/env bash

rm -rf /var/l3afd/l3af-config.json
curl -X POST http://localhost:7080/l3af/configs/v1/add -d "@add_without_chaining_payload.json"
curl http://localhost:7080/l3af/configs/v1/ibpfbr > exp_output_5.json
echo >> exp_output_5.json

curl -X POST http://localhost:7080/l3af/configs/v1/update -d "@upd_without_chaining_payload.json"
curl http://localhost:7080/l3af/configs/v1/ibpfbr > exp_output_6.json
echo >> exp_output_6.json

curl -X POST http://localhost:7080/l3af/configs/v1/delete -d "@del_without_chaining_payload.json"
curl http://localhost:7080/l3af/configs/v1/ibpfbr > exp_output_nil.json
echo >> exp_output_nil.json

curl -X POST http://localhost:7080/l3af/configs/v1/add -d "@add_tm_payload.json"
curl http://localhost:7080/l3af/configs/v1/ibpfbr > exp_output_7.json
echo >> exp_output_7.json

curl -X POST http://localhost:7080/l3af/configs/v1/delete -d "@del_tm_payload.json"
curl http://localhost:7080/l3af/configs/v1/ibpfbr > exp_output_nil.json
echo >> exp_output_nil.json
