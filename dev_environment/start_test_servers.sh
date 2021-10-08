#!/usr/bin/env bash

set -eux

# Host the build artifacts with an HTTP server on port 8000
BUILD_ARTIFACT_DIR=/srv/l3afd

# If BUILD_ARTIFACT_DIR then the provisiniong script hasn't run yet and we
# don't need to start the test servers
if [ ! -d $BUILD_ARTIFACT_DIR ]
then
	exit 0
fi

cd $BUILD_ARTIFACT_DIR
python3 -m http.server 8000 &

# Start the test web servers
go run /vagrant/code/web-server.go -port 8080 > /var/log/web-server1.log 2>&1 &
go run /vagrant/code/web-server.go -port 8081 > /var/log/web-server2.log 2>&1 &
