# Set up L3AF Development Environment for Linux VMs
There are different ways to create a Linux (i.e., Ubuntu 20.04) VM. On a local computer host, various VM software, e.g., VirtualBox, Parallels, Multipass, Windows WSL, etc. can create a Linux VM. A Linux VM can also be created in a cloud environment, e.g., Azure VM. The following procedures illustrate how to set up a L3AF development environment for those VMs if Vagrant doesn't support them.

# Host Prerequisites
* [L3AFD source code](https://github.com/l3af-project/l3afd)
* [curl](https://curl.se/)
* [hey](https://github.com/rakyll/hey) or any HTTP load generator
* A web browser
* A Linux VM running on the host or in a cloud (record the login information while creating the Linux VM, and root access is required.)

# Trying out L3AF
1. Log into the Linux virtual machine, and run "sudo -i" to change to the root user.
2. Run the script `setup_linux_dev_env.sh`

Now go back to the [README.md](README.md) for the host to configure L3AFD to execute sample eBPF programs.
