# L3AF eBPF Package Repository

The concept of a L3AF eBPF Package Repository is to create a location where
eBPF Programs from any trusted party can be uploaded and made available for others to download.

In the context of L3AF, we define an eBPF Package as a kernel space program with
an optional, cooperative user space program.

# What should we name it

"eBPF Package Repository" is the name that has been chosen by the Technical Steering Committee.

# Is the eBPF Package Repository part of the L3AF Project

Firstly, we define the "L3AF Project" as the L3AF open-source project that exists
within The Linux Foundation. When we say "L3AF", we are referring to the entire L3AF Project.
This is not to be confused with:

- The `l3af-project` GitHub organization
- The L3AFD daemon, which is a major component of the L3AF Project.

We consider L3AF to be an entire ecosystem that aims to provide eBPF Programs as a service.
We've otherwise phrased this as "complete lifecycle management of eBPF programs".
This definition includes:

- The L3AFD daemon, an orchestrator that provides APIs to launch and manage eBPF programs on a node
- The L3AF eBPF Package Repository
- Programs within the eBPF Package Repository

Note, however, that we have no intention of limiting the creation of other public or private
eBPF Package repositories.

We recognize that it may make sense to migrate the eBPF Package Repository
(eBPF Programs within the repository) out of the L3AF Project and into its own
Linux Foundation project in the future. Doing this initially may not make sense (due to L3AF-specific
eBPF program chaining implementation for networking programs), but as L3AF and other projects mature,
a platform-agnostic repository could be useful for multiple projects.

# What should an initial version look like

This section examines simple ways to create a location where eBPF Programs can be uploaded
and made available for others to download.

## A GitHub repository may be sufficient

We would like to leverage GitHub:

- A new GitHub repository will be created to store eBPF program source code
- All submissions will be manually reviewed by the L3AF team
- Once approved, programs will be published in the eBPF Package Repository

Another important thing to note is that, initially, code submissions will need
to conform to L3AF's eBPF program chaining mechanics.

## To Build or Not to Build

Because of the overhead and support requirements of a full build system, it may not be
feasible to build the eBPF program source code in the initial version. However, we believe
this would greatly hinder adoption from both contributors and users. Our proposal, therefore,
is to have the repository’s initial version include scripts (e.g. Dockerfile for build system images),
and steps to build eBPF Programs locally.

## eBPF Package Repository of the future

Future versions could build on top of the foundation laid by the initial version.

# What should a future version look like

This section examines simple ways to create a location where eBPF Programs from trusted parties
can be uploaded and made available for others to download. This can also enable users to provide
rating, reviews, and tags to the packages.

### Build Process

Contributed eBPF programs can be built on common images for Linux and other platforms.
Contributors are expected to build their code using the most recent image used by our build system.
Contributors could have a choice to build on Linux only or other platforms.

Build artifacts (i.e., eBPF program bytecode and user space binaries) could be stored
in a public file storage repository. Users could download the artifacts directly
from this repository. In fact, such a repository could also be considered the
eBPF Package Repository, and the source repository could be a separate entity.

### Portability

It is hard to discuss a build system without broaching the topic of portability.
The eBPF portability story has improved recently with the introduction of eBPF CO-RE on Linux.
Previous issues with portability and the eBPF CO-RE solution are explained here:

https://nakryiko.com/posts/bpf-portability-and-co-re/

Because an eBPF Package Repository is a place from where contributed eBPF programs (byte code)
can be downloaded to run on a variety of kernel versions, we propose that the repository follows
best practices for compatibility, such as using eBPF CO-RE for Linux. Similar best practices
can be followed on non-Linux platforms as they mature and become available.
The user space components of eBPF programs pose a separate, complicated portability obstacle,
which is compounded by the desire of the L3AF project to support user space programs in multiple
languages. For the initial version of the repository, it should be sufficient to build
(of a compiled language) and unit test for the x86_64 platform. The user space component
should document any installation dependencies it has (e.g., MySQL, Grafana, Python libraries, etc.).
Contributors to the repository would be responsible to provide the necessary build scripts
and configuration.

### Multiple Versions

Regardless of whether the package is built from source or not, eBPF programs should use semantic
versioning. The repository should then host previous versions (in addition to the current version)
in some reasonable manner.

### Automated Reviews

There can be a mechanism to review source code, using tools to detect like code formatting errors,
complexity, code issues, and code duplication. Similarly, vulnerability detection
scanners can be used for artifacts before uploading.

## Alternative to Hosting and Building Source Code

An alternative to the L3AF Project hosting and building contributed source code would be for
contributors to submit or self-host a signed package containing their eBPF programs and any
documentation. The L3AF daemon, by default, would only download and run eBPF programs signed
by trusted parties. This provides a nice segue for us to go into the signing section.

## Signing and Verification

There are three different layers of signing that should be discussed, the signing of the
kernel eBPF program (i.e., byte code), the signing of the eBPF programs package (i.e., an archive
containing the built eBPF program and any associated user space programs) and
signing for Hypervisors (i.e., Virtualization-based Security).

### Signing and verifying eBPF programs

There are efforts underway in the eBPF community for how to sign and verify
Linux eBPF programs, this enables JIT’ed native code:

https://lore.kernel.org/bpf/20211203191844.69709-1-mcroce@linux.microsoft.com/
https://linuxplumbersconf.org/event/11/contributions/947/

Similarly, signing mechanism for other platforms are also being explored.

L3AF can use the best practices that are established for signing and verifying eBPF programs.

### Signing and verifying the eBPF Program package

At a higher level, we also plan to sign and verify eBPF Package.
The package can be signed by its creator using eBPF Package Repository generated/provided
trusted keys. L3AF can, by default, verify the package comes from a trusted source before executing
any programs in the package

### Signing for Hypervisors

This approach needs to be explored based on hypervisor operating systems security policies.

### Define trust

In this context, trusted user and contributor is defined as authorised registered user to the
system, who has credentials to login with RBAC restrictions. Contributor can be given access
to a set of trusted keys.

### Running L3AFD in trusted mode

The package can be signed by its creator using the trusted keys.
L3AFD can have a mechanism to verify that the package is signed using trusted keys and loaded accordingly.

### Running L3AFD in normal mode (not trusted)

L3AFD can bypass verification process before loading any eBPF programs, it is the sole responsibility of
the user to verify and validate the packages.

### User Experience

A priority for future versions of the repository would be to improve the user experience.

Some examples:
- Frontend website
- Searchable
- Rating system
- Reviews
- Buying and selling
- TLS
- Oauth

## Closed Source Contributions

If a public eBPF Program Repository becomes popular, we can imagine that
some contributors may wish to monetize their eBPF Programs. In this case, we
would not be hosting and building the contributors source code, and we would be
hosting only a signed package containing their eBPF Programs.

eBPF licensing information can be found below. The document discusses
"Packaging BPF programs with user space applications."

https://www.kernel.org/doc/Documentation/bpf/bpf_licensing.rst
