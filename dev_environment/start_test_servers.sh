#!/usr/bin/env bash
set -eux

# Start the test web servers
if [ "$1" == "--ci-build" ]; then
  /usr/local/go/bin/go run /root/l3af-arch/dev_environment/code/web-server.go -port 8080 > server1.log 2>&1 &
  /usr/local/go/bin/go run /root/l3af-arch/dev_environment/code/web-server.go -port 8081 > server2.log 2>&1 &
else
  /usr/local/go/bin/go run /vagrant/code/web-server.go -port 8080 &
  /usr/local/go/bin/go run /vagrant/code/web-server.go -port 8081 &
fi
