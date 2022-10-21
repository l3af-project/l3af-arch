# Set up L3AF Development Environment for Linux VMs

There are different ways to create a Linux (i.e., Ubuntu 20.04) VM.  On a local computer host, various VM software, e.g., VirtualBox, Parallels, Multipass, Windows WSL, etc. can create a Linux VM.  A Linux VM can also be created in a cloud environment, e.g., Azure VM.  The following procedures illustrate how to set up a L3AF development environment for those VMs if Vagrant doesn't support them.

# Host Prerequisites

* [L3AFD source code](https://github.com/l3af-project/l3afd)
* [curl](https://curl.se/)
* [hey](https://github.com/rakyll/hey) or any HTTP load generator
* A web browser
* A Linux VM running on the host or in a cloud (record the login information while creating the Linux VM, and root access is required.)

# Trying out L3AF

1. Edit `config.yaml` to point to the [source code](https://github.com/l3af-project/l3afd) on your host machine. This
   code will be mounted by the virtual machine. Additionally, you may modify the
   default ports used on the host to access services on the virtual machine.
   (Note, however, that this document will refer to the default ports.)

2. log into the Linux virtual machine, and run "sudo -i" to change to the root user.

3. Run the script setup_dev_env_linux_vm.sh

4. Run the script start_test_servers.sh

Now go back to the [README.md](README.md) for the host to configure L3AFD to execute sample eBPF programs. 