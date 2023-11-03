#!/usr/bin/env bash

set -eux

# Start the test web servers
/usr/local/go/bin/go run /vagrant/code/web-server.go -port 8080 &
/usr/local/go/bin/go run /vagrant/code/web-server.go -port 8081 &
