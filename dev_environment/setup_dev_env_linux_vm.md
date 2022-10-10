# Set up L3AF Development Environment for Linux VMs

There are different ways to create Linux VM (i.e. Ubuntu 20.04).  At local computer host, various VM software, i.e. VirtualBox, Parallels, Multipass, Windows WSL etc. can create Linux VM (i.e. ubuntu).  And Linux VM can be created in cloud environment, i.e. Azure VM.  The following procedures illustrated how to set up L3AF devlopment environment for those VMs if Vagrant doesn't support them.

# Host Prerequisites

* [L3AFD source code](https://github.com/l3af-project/l3afd)
* [curl](https://curl.se/)
* [hey](https://github.com/rakyll/hey) or any HTTP load generator
* A web browser
* A Linux VM running on the host or in the Cloud (record the login information while creating the Linux VM, and root access is requried.)

# Trying out L3AF

1. Edit `config.yaml` to point to the [source code](https://github.com/l3af-project/l3afd) on your host machine. This
   code will be mounted by the virtual machine. Additionally, you may modify the
   default ports used on the host to access services on the virtual machine.
   (Note, however, that this document will refer to the default ports.)

2. log in the Linux virtual machine, run "sudo -i" to change to the root user.

3. Run the script setup_dev_env.sh

4. Run the sccript start_test_servers.sh

5. On the host, configure L3AFD to execute sample eBPF programs by running
   `curl -X POST http://localhost:37080/l3af/configs/v1/update -d
   "@cfg/payload.json"`.  The `payload.json` file can be inspected and modified
   as desired. For more information on the L3AFD API see the [L3AFD API
   documentation](https://github.com/l3af-project/l3afd/tree/main/docs/api).

6. Verify the eBPF programs from `payload.json` are running by querying the
   L3AFD debug API from the host: `curl http://localhost:38899/kfs/enp0s3`. This
   command assumes `enp0s3` is a valid network interface on the VM.  Change the interface name of the VM if needed.

7. Once again send traffic to the VM web server:
   `hey -n 200 -c 20 http://localhost:18080`. The traffic will now be running
   through the eBPF programs (which may affect results dramatically depending
   on which eBPF programs are running and how they are configured).

8. To see the eBPF program metrics, browse to `http://localhost:33000` on the
   host and login to Grafana with the default username and password of `admin`.
   After logging in you will be able to view the preconfigured dashboards.