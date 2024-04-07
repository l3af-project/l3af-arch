#!/usr/bin/env bash

set -eux

# Copy grafana configs and dashboards into place
mkdir -p /var/lib/grafana/dashboards
chown grafana:grafana /var/lib/grafana/dashboards
cp /vagrant/cfg/grafana/dashboards/*.json /var/lib/grafana/dashboards
chown grafana:grafana /var/lib/grafana/dashboards/*.json
cp /vagrant/cfg/grafana/provisioning/dashboards/l3af.yaml /etc/grafana/provisioning/dashboards
chown root:grafana /etc/grafana/provisioning/dashboards/*.yaml
cp /vagrant/cfg/grafana/provisioning/datasources/l3af.yaml /etc/grafana/provisioning/datasources
chown root:grafana /etc/grafana/provisioning/datasources/*.yaml

# Copy prometheus config and restart prometheus
cp /vagrant/cfg/prometheus.yml /etc/prometheus/prometheus.yml
systemctl daemon-reload
systemctl restart prometheus prometheus-node-exporter

# Start and enable Grafana
systemctl daemon-reload
systemctl start grafana-server
systemctl enable grafana-server.service

# Copy opentelemetry collector config and restart opentelemetry collector
mkdir -p "/etc/otelcol/"
cp /vagrant/cfg/otel-collector-config.yml /etc/otelcol/config.yml
systemctl daemon-reload
./otelcol --config=/etc/otelcol/config.yml &

# Get Linux source code to build our eBPF programs against
# TODO: Support building against the Linux source from the distro's source
# package.
if [ -d "/usr/src/linux" ]
then
    echo "Directory /usr/src/linux exists."
else
    git clone --branch v5.15 --depth 1 https://github.com/torvalds/linux.git /usr/src/linux
fi
LINUX_SRC_DIR=/usr/src/linux
cd $LINUX_SRC_DIR
make defconfig
make prepare
make headers_install

mkdir -p /var/log/l3af
mkdir -p /var/l3afd

BUILD_DIR=$LINUX_SRC_DIR/samples/bpf/

# Where to store the tar.gz build artifacts
BUILD_ARTIFACT_DIR=/srv/l3afd
mkdir -p $BUILD_ARTIFACT_DIR

cd $BUILD_DIR

# Get the eBPF-Package-Repository repo containing the eBPF programs
if [ -d "eBPF-Package-Repository" ]
then
    echo "Directory eBPF-Package-Repository exists."
else
    git clone https://github.com/l3af-project/eBPF-Package-Repository.git
fi
cd eBPF-Package-Repository

# declare an array variable
declare -a progs=("xdp-root" "ratelimiting" "connection-limit" "tc-root" "ipfix-flow-exporter" "traffic-mirroring")

# Distribution code name
distro=`cat /etc/os-release | grep UBUNTU_CODENAME | awk -F= '{print $2}'`

# now loop through the above array and build the L3AF eBPF programs
for prog in "${progs[@]}"
do
	cd $prog
	make
	PROG_ARTIFACT_DIR=$BUILD_ARTIFACT_DIR/$prog/latest/$distro
	mkdir -p $PROG_ARTIFACT_DIR
	mv *.tar.gz $PROG_ARTIFACT_DIR
	cd ../
done
