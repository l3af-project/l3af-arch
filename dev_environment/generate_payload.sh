#!/usr/bin/env bash


if [ $# -ge 1 ] && [ "$1" == "-i" ]; then
	shift;
	echo "This script will change only hostname & interface name if you want more sophisticated configuration Please change payload files manually"
	hm=$(hostname)
	find ./cfg -type f -name "*.json" -exec sed -i "s/l3af-local-test/$hm/g" {} +
	find ./e2e_test -type f -name "*.json" -exec sed -i "s/l3af-test-host/$hm/g" {} +
	find ./cfg -type f -name "*.json" -exec sed -i "s/enp0s3/$1/g" {} +
	find ./e2e_test -type f -name "*.json" -exec sed -i "s/ibpfbr/$1/g" {} +
	#do your stuff 
else
	echo "To run the script: "
	echo "      ./generate_payload.sh -i <interface_name> "	
fi

