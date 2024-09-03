#!/usr/bin/env bash
set -eux

# This script needs to run as root account, check it
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


# Install packages
apt-get update
apt-get install -y apt-transport-https software-properties-common wget dpkg
sudo apt-get install -y adduser libfontconfig1 musl
# Get grafana package
if [ "$arch" == amd64 ];then
   wget https://dl.grafana.com/oss/release/grafana_10.4.1_amd64.deb
   sudo dpkg -i grafana_10.4.1_amd64.deb 
   rm -rf grafana_10.4.1_amd64.deb
elif [ "$arch" == arm64 ];then
   wget https://dl.grafana.com/oss/release/grafana_10.4.1_arm64.deb
   sudo dpkg -i grafana_10.4.1_arm64.deb
   rm -rf grafana_10.4.1_arm64.deb
else
  echo "grafana installation is not available for this cpu architecture"
fi	   
apt-get clean
apt-get update

export DEBIAN_FRONTEND=noninteractive
export TZ=Etc/UTC
# Install all necessary packages
# gcc-multilib does not exist for arm64 repos
apt-get install -y bc \
      tzdata \
      bison \
      build-essential \
      clang \
      curl \
      exuberant-ctags \
      flex \
      gcc-9 \
      gnutls-bin \
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
      rsync    \
      dwarves \
      zlib1g  \
      libelf1 \
      pkg-config

# Install OTEL collector
if [ $# -ge 1 ] && [ "$1" == "--otel-collector" ]; then
  OTEL_VERSION="0.97.0"
  case $ARCH in
    arm)
      echo "Installing OTELC for arm"
      OTEL_ARCH="arm"
      ;;

    aarch64)
      echo "Installing OTELC for arm"
      OTEL_ARCH="arm64"
      ;;

    x86_64)
      echo "Installing OTELC for amd64"
      OTEL_ARCH="amd64"
      ;;
    i386)
      KERNEL=$(uname -m)
      if [ "$KERNEL" = "x86_64" ];
      then
        echo "Installing OTELC for amd64"
        OTEL_ARCH="amd64"
      elif [ "$KERNEL" = "i386" ];
      then
        echo "Installing OTELC for i386"
        OTEL_ARCH="386"
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
  OTEL_BINARY="otelcol_${OTEL_VERSION}_linux_${OTEL_ARCH}.tar.gz"
  OTEL_DIR="otelcol_${OTEL_VERSION}_linux_${OTEL_ARCH}"
  curl --proto '=https' --tlsv1.2 -fOL "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTEL_VERSION}/${OTEL_BINARY}"
  tar -xvf ${OTEL_BINARY}
  sudo mv ${OTEL_DIR}/otelcol /usr/local/bin/otelcol
  sudo chmod +x /usr/local/bin/otelcol
  rm -rf ${OTEL_BINARY}
  echo "OTEL Collector version ${OTEL_VERSION} installed successfully."
fi


# Install the latest go lang version
  os=`uname|tr '[:upper:]' '[:lower:]'`
  go_filename=`curl -s https://go.dev/dl/?mode=json|jq '.[0].files[].filename'|grep $os|grep $arch|egrep -v "ppc"|tr -d '"'`
  wget https://go.dev/dl/$go_filename
  tar -C /usr/local -xzf $go_filename && rm -f $go_filename
  export PATH=$PATH:/usr/local/go/bin
  echo export PATH=$PATH:/usr/local/go/bin >> /root/.bashrc


# Clone the l3afd repo in to root directly
# Can use mapped directory i.e. at /home/ubuntu/Home
if [ ! -d "/root/l3afd" ];
then
  git clone https://github.com/l3af-project/l3afd.git
else
  echo "/root/l3afd directory already exists"
fi

if [ ! -d "/root/l3af-arch" ];
then
  git clone https://github.com/l3af-project/l3af-arch.git
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

# Copy OTEL collector config and start OTEL collector
if [ $# -ge 1 ] && [ "$1" == "--otel-collector" ]; then
  echo "Copying OTEL Collector config."
  mkdir -p "/etc/otelcol/"
  cp /root/l3af-arch/dev_environment/cfg/otel-collector-config.yml /etc/otelcol/config.yml
fi


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

  # Start OTEL collector
  if [ $# -ge 1 ] && [ "$1" == "--otel-collector" ]; then
    /usr/local/bin/otelcol --config=/etc/otelcol/config.yml &
  else
    echo "Skipping OTEL collector binary startup."
  fi
else
  # The configuration got copied, restart the prometheus service
  systemctl daemon-reload
  systemctl restart prometheus prometheus-node-exporter
  systemctl enable prometheus.service
  systemctl enable prometheus-node-exporter.service

  # Start and enable Grafana
  systemctl restart grafana-server
  systemctl enable grafana-server.service

  # Start OTEL collector
  if [ $# -ge 1 ] && [ "$1" == "--otel-collector" ]; then
    /usr/local/bin/otelcol --config=/etc/otelcol/config.yml &
  else
    echo "Skipping OTEL collector binary startup."
  fi
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
sed -i '229a\
        if [ "${pahole_ver}" -ge "124" ]; then\
                extra_paholeopt="${extra_paholeopt} --skip_encoding_btf_enum64"\
        fi' scripts/link-vmlinux.sh

echo "CONFIG_DEBUG_INFO_BTF=y" >> .config
echo "CONFIG_MODULES=y" >> .config
make olddefconfig
make prepare
yes | make -j$(nproc)
make headers_install

if [ ! -d "/var/log/l3af" ];
then
  mkdir -p /var/log/l3af
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

if [ "$(which bpftool)" == "" ]; 
then
  git clone --branch v7.2.0 --recurse-submodules https://github.com/libbpf/bpftool.git
  cd bpftool/src
  yes | make
  cp bpftool /usr/local/bin/
  cd ../../
  rm -rf bpftool
fi

# Declare an array variable
declare -a progs=("xdp-root" "ratelimiting" "connection-limit" "tc-root" "ipfix-flow-exporter" "traffic-mirroring")
codename=`lsb_release -c -s`
# Now loop through the above array and build the L3AF eBPF programs
for prog in "${progs[@]}"
do
	cd $prog
	make
	PROG_ARTIFACT_DIR=$BUILD_ARTIFACT_DIR/$prog/latest/$codename
	mkdir -p $PROG_ARTIFACT_DIR
	mv *.tar.gz $PROG_ARTIFACT_DIR
	cd ../
done

# Compile L3AFD daemon and start the control plane
cd /root/l3afd
make install

chmod +rx /root/l3af-arch/dev_environment/start_test_servers.sh
mkdir -p /usr/local/l3afd/latest
mkdir -p /usr/local/l3afd/v2/l3afd

# for dev purposes I made simlink for v2 version to your local
ln -s /root/go/bin/l3afd /usr/local/l3afd/v2/l3afd/l3afd
ln -s /root/l3af-arch/dev_environment/cfg/l3afd.cfg /usr/local/l3afd/v2/l3afd.cfg

cd /usr/local/l3afd/latest
ln -s /usr/local/l3afd/v2/l3afd/l3afd l3afd
ln -s /usr/local/l3afd/v2/l3afd/l3afd.cfg l3afd.cfg


# Starting test servers and l3afd daemon
if [ $# -ge 1 ] && [ "$1" == "--ci-build" ]; then  
  # Test coverdata
  mkdir -p /root/coverdata
  mkdir -p /root/coverdata/int
  mkdir -p /root/coverdata/unit
  mkdir -p /root/coverdata/combined
  export GOCOVERDIR="/root/coverdata/int"
  echo export GOCOVERDIR="/root/coverdata/int" >> /root/.bashrc
  cd /root/l3afd
  make cibuild
  /root/l3af-arch/dev_environment/start_test_servers.sh --ci-build
  ip netns exec bpf bash /root/l3af-arch/dev_environment/start_test_servers.sh --ci-build
  /usr/local/l3afd/latest/l3afd --config /usr/local/l3afd/latest/l3afd.cfg > l3afd.log 2>&1 &
elif [ $# -ge 1 ] && [ "$1" == "--docker" ]; then
  echo "Running L3AFD as a docker container"
  apt-get install -y docker docker.io
  cd /root/l3afd/build-docker
  cp /root/go/bin/l3afd .
  cp /root/l3afd/config/l3afd.cfg .
  /root/l3af-arch/dev_environment/start_test_servers.sh
  docker build -t l3afd:latest -f Dockerfile .
  docker images
  docker run -d -v /srv/l3afd:/srv/l3afd -v /sys/fs/bpf:/sys/fs/bpf -v /sys/kernel/debug/:/sys/kernel/debug/ -v /dev/shm:/dev/shm --privileged --net=host l3afd:latest
  docker logs $(docker ps -q)
else
  /root/l3af-arch/dev_environment/start_test_servers.sh
  /usr/local/l3afd/latest/l3afd --config /usr/local/l3afd/latest/l3afd.cfg &
fi

