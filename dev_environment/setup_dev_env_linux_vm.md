# Set up L3AF Development Environment for Linux VMs

There are different ways to create Linux VM (i.e. Ubuntu 20.04).  At local computer host, various VM software, i.e. VirtualBox, Parallels, Multipass, Windows WSL etc. can create Linux VM (i.e. ubuntu).  And Linux VM can be created in cloud environment, i.e. Azure VM.  The following procedures illustrated how to set up L3AF development environment for those VMs if Vagrant doesn't support them.

# Host Prerequisites

* [L3AFD source code](https://github.com/l3af-project/l3afd)
* [curl](https://curl.se/)
* [hey](https://github.com/rakyll/hey) or any HTTP load generator
* A web browser
* A Linux VM running on the host or in the Cloud (record the login information while creating the Linux VM, and root access is required.)

# Trying out L3AF

1. Edit `config.yaml` to point to the [source code](https://github.com/l3af-project/l3afd) on your host machine. This
   code will be mounted by the virtual machine. Additionally, you may modify the
   default ports used on the host to access services on the virtual machine.
   (Note, however, that this document will refer to the default ports.)

2. log in the Linux virtual machine, run "sudo -i" to change to the root user.

3. Run the script setup_dev_env_linux_vm.sh

4. Run the sccript start_test_servers.sh

Now go back the [README.md](https://github.com/l3af-project/l3af-arch/blob/main/dev_environment/README.md) for the host to configure L3AFD to execute sample eBPF programs. 