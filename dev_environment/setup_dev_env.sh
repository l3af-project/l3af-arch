#!/usr/bin/env bash

set -eux

# this script need to run as root account, check it
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# Get cpu architecture, arm or amd
ARCH=$(uname -p)
if [[ "$ARCH" = "arm" ||  "$ARCH" = "aarch64" ]];
then
echo "Setting l3af dev environment for arm"
elif [ "$ARCH" = "x86_64" ];
then
echo "Setting l3af dev environment for amd64"
fi

cd /root

# install packages
apt-get update
apt-get install -y apt-transport-https
apt-get install -y software-properties-common wget

# get grafana package
wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -
echo "deb https://packages.grafana.com/oss/deb stable main" | tee -a /etc/apt/sources.list.d/grafana.list
apt-get clean
apt-get update
# -end-

# install all necessary packages
# gcc-multilib      not existed for arm64 repos
# golang            default version 1.13 not working, install 1.17 below
apt-get install -y bc \
      bison \
      build-essential \
      clang \
      curl \
      exuberant-ctags \
      flex \
      gcc-8 \
      gnutls-bin \
      grafana \
      libc6-dev \
      libcurl4-openssl-dev \
      libelf-dev \
      libjson-c-dev \
      libncurses5-dev \
      libpcap-dev \
      libssl-dev \
      linux-headers-generic \
      linux-tools-common \
      linux-tools-generic \
      llvm \
      prometheus \
      rsync

#install go lang version 1.17.12
if [ -d "/usr/local/go/bin" ];
then
  echo "golang already installed"
else
        if [[ "$ARCH" = "arm" ||  "$ARCH" = "aarch64" ]];
        then
                wget https://go.dev/dl/go1.17.12.linux-arm64.tar.gz
                tar -C /usr/local -xzf go1.17.12.linux-arm64.tar.gz
        elif [ "$ARCH" = "x86_64" ];
        then
                wget https://go.dev/dl/go1.17.12.linux-amd64.tar.gz
                tar -C /usr/local -xzf go1.17.12.linux-amd64.tar.gz
        fi
fi
export PATH=$PATH:/usr/local/go/bin

# clone the l3afd repo in to root directly
# can use mapped directory i.e. at /home/ubuntu/Home
if [ -d "/root/l3afd" ];
then
  echo "repo already exited"
else
  git clone https://github.com/l3af-project/l3afd.git
  git clone https://github.com/l3af-project/l3af-arch.git
fi

# Copy grafana configs and dashboards into place
if [ -d "/var/lib/grafana/dashboards"];
then
  echo "grafana directory already existed"
else
  mkdir -p /var/lib/grafana/dashboards
fi
chown grafana:grafana /var/lib/grafana/dashboards
cp /root/l3af-arch/dev_environment/cfg/grafana/dashboards/*.json /var/lib/grafana/dashboards
chown grafana:grafana /var/lib/grafana/dashboards/*.json
cp /root/l3af-arch/dev_environment/cfg/grafana/provisioning/dashboards/l3af.yaml /etc/grafana/provisioning/dashboards
chown root:grafana /etc/grafana/provisioning/dashboards/*.yaml
cp /root/l3af-arch/dev_environment/cfg/grafana/provisioning/datasources/l3af.yaml /etc/grafana/provisioning/datasources
chown root:grafana /etc/grafana/provisioning/datasources/*.yaml

# Copy prometheus config and restart prometheus
cp /root/l3af-arch/dev_environment/cfg/prometheus.yml /etc/prometheus/prometheus.yml
if uname -a | grep -q 'WSL'; then
        echo "WSL DETECTED"
        apt-get install daemon
        #start/restart prometheus-node-exporter
        /etc/init.d/prometheus-node-exporter start
        /etc/init.d/prometheus-node-exporter stop
        /etc/init.d/prometheus-node-exporter start

        # Start and enable Grafana
        sleep 1
        /etc/init.d/grafana-server stop || true
        /etc/init.d/grafana-server stop || true
        /etc/init.d/grafana-server start || true
else
  systemctl daemon-reload
  systemctl restart prometheus prometheus-node-exporter

  # Start and enable Grafana
  systemctl daemon-reload
  systemctl start grafana-server
  systemctl enable grafana-server.service
fi

# Get Linux source code to build our eBPF programs against
if [ ! -d "/usr/src/linux" ];
then
  git clone --branch v5.1 --depth 1 https://github.com/torvalds/linux.git /usr/src/linux
fi
LINUX_SRC_DIR=/usr/src/linux
cd $LINUX_SRC_DIR
make defconfig

if [ ! -d "/var/log/tb/l3af" ];
then
  mkdir -p /var/log/tb/l3af
fi
if [ ! -d "/var/l3afd" ];
then
  mkdir -p /var/l3afd
fi

BUILD_DIR=$LINUX_SRC_DIR/samples/bpf/

# Where to store the tar.gz build artifacts
BUILD_ARTIFACT_DIR=/srv/l3afd
if [ ! -d "$BUILD_ARTIFACT_DIR"];
then
  mkdir -p $BUILD_ARTIFACT_DIR
fi

cd $BUILD_DIR

# Get the eBPF-Package-Repository repo containing the eBPF programs
if [ ! -d "$BUILD_DIR/eBPF-Package-Repository" ];
then
  git clone https://github.com/l3af-project/eBPF-Package-Repository.git
fi
cd eBPF-Package-Repository

# declare an array variable
declare -a progs=("xdp-root" "ratelimiting" "connection-limit" "tc-root" "ipfix-flow-exporter")

# now loop through the above array and build the L3AF eBPF programs
for prog in "${progs[@]}"
do
	cd $prog
	make
	PROG_ARTIFACT_DIR=$BUILD_ARTIFACT_DIR/$prog/latest/focal
	mkdir -p $PROG_ARTIFACT_DIR
	mv *.tar.gz $PROG_ARTIFACT_DIR
	cd ../
done

# Compile L3AFD damon and start the control plan
cd /root/l3afd
go install
cd ../go/bin/
./l3afd --config /root/l3af-arch/dev_environment/cfg/l3afd.cfg &