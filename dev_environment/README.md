# L3AF Development Environment

The L3AF dev environment is a [Vagrant](https://www.vagrantup.com/) virtual
machine environment that allows users to develop, test, or just try out L3AF.

# Overview

The L3AF dev environment automation sets up a virtual machine that contains:

* Dependencies required to build L3AFD and Kernel Functions (i.e., eBPF
  programs)
* Simple web servers (written in Go) to which test traffic can be sent
* Prometheus and Grafana for metrics
* A local Kernel Function repository (simple Python file server)

The host machine can access various services on the virtual machine via
user-configured ports.

Here is a visual overview:

![L3AF dev env overview](../images/L3AF_dev_env.png)

# Host Prerequisites

* [Vagrant](https://www.vagrantup.com/)
* [VirtualBox](https://www.virtualbox.org/)
* [ssh-agent](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)
* [L3AFD source code](https://github.com/l3af-project/l3afd)
* [curl](https://curl.se/)
* [hey](https://github.com/rakyll/hey) or any HTTP load generator
* A web browser

# Trying out L3AF

* Edit `config.yaml` to point to the [source code](https://github.com/l3af-project/l3afd) on your host machine. This
  code will be mounted by the virtual machine. Additionally, you may modify the
  default ports used on the host to access services on the virtual machine.
  (Note, however, that this document will refer to the default ports.)
* If you don't already have the vagant reload plugin, you'll need to install it,
    `vagrant plugin install vagrant-reload`.
* Run `ssh -T git@github.com` to verify if ssh-agent can access matching private key, run `ssh-add` to add identity to the authentication agent.
* Run `vagrant up`. This should take just a few minutes to bring up the
  virtual machine from scratch.
* Verify that the host can send traffic to a web server running on the VM:
  `hey -n 200 -c 20 http://localhost:18080`. This command should return quickly
  and result in successful HTTP responses (200 OK).
* Run `vagrant ssh`, this will log you into the virtual machine
* On the VM, go to `~/code/l3afd` and run `go install .`
* On the VM, go to `~/go/bin` and run `l3afd` as root:
  `sudo ./l3afd --config /vagrant/cfg/l3afd.cfg`
* On the host, configure L3AFD to execute sample Kernel Functions by running
  `curl -X POST http://localhost:37080/l3af/configs/v1/update -d
  "@cfg/payload.json"`.  The `payload.json` file can be inspected and modified
  as desired. For more information on the L3AFD API see the [L3AFD API
  documentation](https://github.com/l3af-project/l3afd/tree/main/docs/api).
* Verify the eBPF programs from `payload.json` are running by querying the
  L3AFD debug API from the host: `curl http://localhost:38899/kfs/enp0s3`. This
  command assumes `enp0s3` is a valid network interface on the VM.
* Once again send traffic to the VM web server:
  `hey -n 200 -c 20 http://localhost:18080`. The traffic will now be running
  through the Kernel Functions (which may affect results dramatically depending
  on which Kernel Functions are running and how they are configured).
* To see the Kernel Function metrics, browse to `http://localhost:33000` on the
  host and login to Grafana with the default username and password of `admin`.
  After logging in you will be able to view the preconfigured dashboards.
