# L3AF Development Environment

The L3AF dev environment is a [Vagrant](https://www.vagrantup.com/) virtual
machine environment that allows users to develop, test, or just try out L3AF.

# Overview

The L3AF dev environment automation sets up a virtual machine that contains:

* Dependencies required to build L3AFD and eBPF programs
* Simple web servers (written in Go) to which test traffic can be sent
* Prometheus and Grafana for metrics
* A local eBPF Package Repository (simple Python file server)

The host machine can access various services on the virtual machine via
user-configured ports.

Here is a visual overview:

![L3AF dev env overview](../images/L3AF_dev_env.png)

# Trying out L3AF on Local Machine
The following host prerequisites and installation instructions are for trying out L3AF on your local machine.

## Host Prerequisites

* [Vagrant](https://www.vagrantup.com/)
* [VirtualBox](https://www.virtualbox.org/)
* [L3AFD source code](https://github.com/l3af-project/l3afd)
* [curl](https://curl.se/)
* [hey](https://github.com/rakyll/hey) or any HTTP load generator
* A web browser

## Installation Instructions
1. Edit `config.yaml` to point to the [source code](https://github.com/l3af-project/l3afd) on your host machine. This
  code will be mounted by the virtual machine. Additionally, you may modify the
  default ports used on the host to access services on the virtual machine.
  (Note, however, that this document will refer to the default ports.)
2. If you don't already have the vagant reload plugin, you'll need to install it,
    `vagrant plugin install vagrant-reload`.
3. Run `vagrant up`. This should take just a few minutes to bring up the
  virtual machine from scratch.
4. Verify that the host can send traffic to a web server running on the VM:
  `hey -n 200 -c 20 http://localhost:18080`. This command should return quickly
  and result in successful HTTP responses (200 OK).
5. Run `vagrant ssh`, this will log you into the virtual machine
6. On the VM, go to `~/code/l3afd` and run `go install .`
7. On the VM, go to `~/go/bin` and run `l3afd` as root:
  `sudo ./l3afd --config /vagrant/cfg/l3afd.cfg`
8. On the host, configure L3AFD to execute sample eBPF programs by running
  `curl -X POST http://localhost:37080/l3af/configs/v1/update -d
  "@cfg/payload.json"`.  The `payload.json` file can be inspected and modified
  as desired. For more information on the L3AFD API see the [L3AFD API
  documentation](https://github.com/l3af-project/l3afd/tree/main/docs/api).
9. Verify the eBPF programs from `payload.json` are running by querying the
  L3AFD debug API from the host: `curl http://localhost:38899/kfs/enp0s3`. This
  command assumes `enp0s3` is a valid network interface on the VM.
10. Once again send traffic to the VM web server:
  `hey -n 200 -c 20 http://localhost:18080`. The traffic will now be running
  through the eBPF programs (which may affect results dramatically depending
  on which eBPF programs are running and how they are configured).
11. To see the eBPF program metrics, browse to `http://localhost:33000` on the
  host and login to Grafana with the default username and password of `admin`.
  After logging in you will be able to view the preconfigured dashboards.

# Trying out L3AF on an Azure VM (Ubuntu 20.04.4 LTS)
The following host prerequisites and installation instructions are for trying out L3AF on an Azure VM running an Ubuntu 20.04.4 LTS server.

## Host Prerequisites

* [L3AFD source code](https://github.com/l3af-project/l3afd)
* [hey](https://github.com/rakyll/hey) or any HTTP load generator
* A web browser
* [Go for Linux](https://go.dev/doc/install) version 1.18.4 or greater

## Installation Instructions
1. Clone the [l3afd](https://github.com/l3af-project/l3afd.git) and [l3af-arch](https://github.com/l3af-project/l3af-arch.git)
Github repositories to your Azure VM.
2. Download and install Go for Linux version 1.18.4 or greater at https://go.dev/doc/install. Make sure that you do **not** use `sudo apt install`,
because this command will install version 1.13 but the installation requires version 1.17 at the minimum.
3. Edit `config.yaml` to point to the [L3AFD repository](https://github.com/l3af-project/l3afd) on your host machine.
4. Run `install.sh` to install package dependencies, Grafana, Prometheus, the eBPF source code you need to build your eBPF programs against,
and the eBPF package repository.
5. On the Azure VM, go to your L3AFD directory and run `go install .`
6. On the Azure VM, go to `~/go/bin` and run `l3afd` as root:
  `sudo ./l3afd --config /vagrant/cfg/l3afd.cfg`.

## Trying out your L3AFD Server
1. Start test web servers by running the following commands on your Azure VM: `go run l3af-arch/dev_environment/code/web-server.go -port 8080 > /var/log/web-server1.log 2>&1 &` and `go run l3af-arch/dev_environment/code/web-server.go -port 8081 > /var/log/web-server1.log 2>&1 &`.
2. Verify that no eBPF programs are running by querying the
L3AFD server from your laptop: `curl http://<ip-address-of-your-azure-vm>:8899/kfs/eth0`. This
command assumes `eth0` is a valid network interface on the VM and should return with an empty set.
3. Verify that you can send traffic to one of the test web servers running on the Azure VM with this command:
`hey -n 200 -c 20 http://<ip-address-of-your-azure-vm>:8080`. This command should return a latency distribution histogram that shows
 most traffic clustered near the top of the graph at very low latency.
4. Load and run the ratelimiter eBPF program in the kernel with the following command: `curl -X POST http://<ip-address-of-your-azure-vm>:7080/l3af/configs/v1/update -d "@payload.json"`.
5. Query the L3AFD server again to ensure that the ratelimiter eBPF program was loaded into the kernel and is running: `curl http://<ip-address-of-your-vm>:8899/kfs/eth0`. This query should output a .json file similar to this: https://github.com/l3af-project/l3afd/tree/main/docs/api.
6. Generate traffic again: `hey -n 200 -c 20 http://<ip-address-of-your-vm>:8080`. This command should now output a latency distribution histogram that
is more distributed because the ratelimiter eBPF program is in operation.
