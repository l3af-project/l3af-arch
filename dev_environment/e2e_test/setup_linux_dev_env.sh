#!/usr/bin/env bash

set -eux

# this script needs to run as root account, check it
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# Check for kernel version 5.15
CURRENT_KERNEL_VERSION=$(uname -r | cut -d"." -f1-2)
CURRENT_KERNEL_MAJOR_VERSION=$(echo "${CURRENT_KERNEL_VERSION}" | cut -d"." -f1)
CURRENT_KERNEL_MINOR_VERSION=$(echo "${CURRENT_KERNEL_VERSION}" | cut -d"." -f2)
ALLOWED_KERNEL_VERSION="5.15"
ALLOWED_KERNEL_MAJOR_VERSION=$(echo ${ALLOWED_KERNEL_VERSION} | cut -d"." -f1)
ALLOWED_KERNEL_MINOR_VERSION=$(echo ${ALLOWED_KERNEL_VERSION} | cut -d"." -f2)
if [ "${CURRENT_KERNEL_MAJOR_VERSION}" -lt "${ALLOWED_KERNEL_MAJOR_VERSION}" ]; then
  # If the current major version is less than the allowed major version, show an error message and exit.
  echo "Error: Kernel ${CURRENT_KERNEL_VERSION} not supported, please update to ${ALLOWED_KERNEL_VERSION}."
  exit
fi
if [ "${CURRENT_KERNEL_MAJOR_VERSION}" == "${ALLOWED_KERNEL_MAJOR_VERSION}" ]; then
  # If the current major version is equal to the allowed major version, check the minor version.
  if [ "${CURRENT_KERNEL_MINOR_VERSION}" -lt "${ALLOWED_KERNEL_MINOR_VERSION}" ]; then
    # If the current minor version is less than the allowed minor version, show an error message and exit.
    echo "Error: Kernel ${CURRENT_KERNEL_VERSION} not supported, please update to ${ALLOWED_KERNEL_VERSION}."
    exit
  fi
fi

# Get cpu architecture, arm or amd
ARCH=$(uname -p)

case $ARCH in
  arm)
    echo "Setting l3af dev environment for arm"
    arch=arm64
    ;;

  aarch64)
    echo "Setting l3af dev environment for arm"
    arch=arm64
    ;;

  x86_64)
    echo "Setting l3af dev environment for amd64"
    arch=amd64
    ;;

  i386)
    KERNEL=$(uname -m)
    if [ "$KERNEL" = "x86_64" ];
    then
      echo "Setting l3af dev environment for amd64"
      arch=amd64
    elif [ "$KERNEL" = "i386" ];
    then
      echo "Setting l3af dev environment for i386"
      arch=386
    else
      echo "The CPU kernel $KERNEL is not supported by the script"
      exit 1
    fi
  ;;

  *)
    echo "The CPU architecture $ARCH is not supported by the script"
    exit 1
  ;;
esac

cd /root

# install packages
apt-get update 
apt-get install -y software-properties-common wget

# get grafana package
wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -
echo "deb https://packages.grafana.com/oss/deb stable main" | tee -a /etc/apt/sources.list.d/grafana.list
apt-get clean
apt-get update
# -end-

# install all necessary packages
# gcc-multilib      not existed for arm64 repos
apt-get install -y bc \
      bison \
      build-essential \
      clang \
      curl \
      exuberant-ctags \
      flex \
      gcc-9 \
      gnutls-bin \
      grafana \
      jq \
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
      rsync \
      linux-tools-5.15.0-78-generic

#install the latest go lang version
  os=`uname|tr '[:upper:]' '[:lower:]'`
  go_filename=`curl -s https://go.dev/dl/?mode=json|jq '.[0].files[].filename'|grep $os|grep $arch|egrep -v "ppc"|tr -d '"'`
  wget https://go.dev/dl/$go_filename
  tar -C /usr/local -xzf $go_filename && rm -f $go_filename
  export PATH=$PATH:/usr/local/go/bin
  echo export PATH=$PATH:/usr/local/go/bin >> /root/.bashrc

if [ ! -d "/root/l3af-arch" ];
then
  git clone -b E2E https://github.com/Atul-source/l3af-arch.git
else
  echo "/root/l3af-arch directory already exists"
fi

# Copy grafana configs and dashboards into place
if [ -d "/var/lib/grafana/dashboards" ];
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
if uname -a | grep -q 'WSL';
then
  echo "WSL DETECTED"
  apt-get install daemon
  /etc/init.d/prometheus-node-exporter stop
  /etc/init.d/prometheus-node-exporter start

  # Start and enable Grafana
  sleep 1
  /etc/init.d/grafana-server stop || true
  /etc/init.d/grafana-server start || true
else
  # the configuration got copied, restart the prometheus service
  systemctl daemon-reload
  systemctl restart prometheus prometheus-node-exporter
  systemctl enable prometheus.service
  systemctl enable prometheus-node-exporter.service

  # Start and enable Grafana
  systemctl restart grafana-server
  systemctl enable grafana-server.service
fi

# Get Linux source code to build our eBPF programs against
if [ -d "/usr/src/linux" ];
then
  echo "Linux source code already exists, skipping download"
else
  git clone --branch v5.15 --depth 1 https://github.com/torvalds/linux.git /usr/src/linux
fi

LINUX_SRC_DIR=/usr/src/linux
cd $LINUX_SRC_DIR
make defconfig
make prepare
make headers_install

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
if [ ! -d "$BUILD_ARTIFACT_DIR" ];
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
declare -a progs=("xdp-root" "ratelimiting" "connection-limit" "tc-root" "ipfix-flow-exporter" "traffic-mirroring")

# now loop through the above array and build the L3AF eBPF programs
for prog in "${progs[@]}"
do
	cd $prog
	make
	PROG_ARTIFACT_DIR=$BUILD_ARTIFACT_DIR/$prog/latest/jammy
	mkdir -p $PROG_ARTIFACT_DIR
	mv *.tar.gz $PROG_ARTIFACT_DIR
	cd ../
done

# Compile L3AFD daemon and start the control plane
cd /root/l3afd
make install
cd ../go/bin/


# start l3afd
./l3afd --config /root/l3af-arch/dev_environment/cfg/l3afd.cfg > l3afd.log 2>&1 &
