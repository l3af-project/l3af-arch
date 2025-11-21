#!/usr/bin/env bash

rm -rf /var/l3afd/l3af-config.json
curl -X POST http://localhost:7080/l3af/configs/v1/add -d "@add_payload.json"
curl http://localhost:7080/l3af/configs/v1/ibpfbr > exp_output_1.json
echo >> exp_output_1.json

curl -X POST http://localhost:7080/l3af/configs/v1/update -d "@upd_payload.json"
curl http://localhost:7080/l3af/configs/v1/ibpfbr > exp_output_2.json
echo >> exp_output_2.json

curl -X POST http://localhost:7080/l3af/configs/v1/add -d "@add_tm_payload.json"
curl http://localhost:7080/l3af/configs/v1/ibpfbr > exp_output_3.json
echo >> exp_output_3.json

curl -X POST http://localhost:7080/l3af/configs/v1/delete -d "@del_ipfix_payload.json"
curl http://localhost:7080/l3af/configs/v1/ibpfbr > exp_output_4.json
echo >> exp_output_4.json

curl -X POST http://localhost:7080/l3af/configs/v1/delete -d "@del_payload.json"
curl http://localhost:7080/l3af/configs/v1/ibpfbr > exp_output_nil.json
echo >> exp_output_nil.json
