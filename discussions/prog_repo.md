# L3AF Kernel Function Marketplace

The concept of a L3AF Kernel Function Marketplace is to create a location where
Kernel Functions from any trusted party can be uploaded and made available for
others to download.

In the context of L3AF, we define a Kernel Function a kernel eBPF program with
an optional, cooperative userspace program.

There are many things to consider. At the highest level, the purpose of this
discussion is to arrive an conclusions for:

- What should we name it
- Is the Kernel Function Marketplace part of the L3AF project?
- What should an initial version look like
- What should a more mature version look like

# What should we name it

"L3AF Kernel Function Marketplace" has been the name used up to this point and
will continue to be the name unless changed by the Technical Steering
Committee.

This topic is open for discussion.

# Is the Kernel Function Marketplace part of the L3AF Project

Firstly, we define the "L3AF Project" as entire L3AF open source project that
exists within The Linux Foundation. When we say "L3AF" we are referring to the
entire L3AF Project. This is not to be configured with:

- The `l3af-project` Github organization
- The L3AFD daemon, which is just one piece of the L3AF Project.

We consider L3AF to be an entire ecosystem of Kernel Functions as a
service. We've otherwise phrased this as "complete lifecycle management of eBPF
programs." This definition includes:

- The L3AFD daemon, which manages and executes eBPF programs on a node
- The L3AF Kernel Function Marketplace
- Programs within the Kernel Function Marketplace

Note, however, that we have no intention of limiting the creation of other
public or private Kernel Function Marketplaces.

Additionally, we recognize that it may make sense to migrate the Kernel
Function marketplace (and Kernel Functions within the marketplace) out of the
L3AF project and into its own project in the future. Doing this initially may
not make sense (due to L3AF-specific eBPF program chaining mechanics, for
example), but as L3AF and other projects mature, a platform-agnostic
marketplace could be useful for multiple projects.

# What should an initial version look like

This sections examines relatively simply ways that we can create a location
where Kernel Functions from trusted parties can be uploaded and made available
for others to download.

## A GitHub repository may be sufficient
 
We could leverage GitHub:
- A new GitHub repository could be created to store kernel function source code
- All submissions could be reviewed by the L3AF team
- Once approved, users could download the kernel function (source and any build
  artifacts)

If we use this approach, this GitHub repo could be created under
github.com/leaf-project.

Kernel functions could be arranged by file path and categorized in any number
of ways. For example, using a schema such as: 

`/{Program Category}/{Program Subcategory}/{Submitter}/{Program Name}`

Could translate to a kernel function being stored at:

`/Security/limits/Walmart/ratelimit`

Another important thing to note is that, initially, code submissions will need
to conform to L3AF's eBPF program chaining mechanics.

## To Build or Not to Build

For the initial version, we could choose to not build the Kernel Function
source code. However, we believe that not providing a build system would
greatly hinder adoption from both contributors and users. Therefore, we propose
that the initial version of the marketplace include a automated build system.

### Portability

It's hard to discuss a build system without broaching the topic of portability.
Luckily, the eBPF portability story has improved fairly recently with the
introduction of eBPF CO-RE.

Previous issues with portability and the eBPF CO-RE solution are explained
here:

https://nakryiko.com/posts/bpf-portability-and-co-re/

Because a Kernel Function Marketplace would doubtlessly be a place where
contributed eBPF programs would be downloaded to run on a variety of kernel
versions, we propose that the marketplace only contain eBPF CO-RE programs. 

The userspace components of kernel functions pose a separate, complicated
portability obstacle, which is compounded by the desire of the L3AF project to
support userspace programs in multiple languages. For the initial version of
the marketplace, it should be sufficient to build (if a compiled language) and
unit test for the x86_64 platform. The userspace component should also document
any installation dependencies it has (e.g., MySQL, Grafana, Python libraries,
etc.). Contributors to the marketplace would be responsible to provide the
necessary build scripts and configuration. 

### Build Process

Ideally, we would build on a common image (and kernel version) for all
contributed eBPF programs. We believe eBPF CO-RE would allow us to do this.
Contributors would be expected to keep their code building on the most recent
image used by our build system.

The image used for our build system could be the most recent release of a
popular Linux server distribution, for example. Here is some information on the
distros that support eBPF CO-RE be default:

https://github.com/libbpf/libbpf#bpf-co-re-compile-once--run-everywhere

Userspace programs would also ideally build on a common image.

Build artifacts (i.e., eBPF program bytecode and userspace binaries) would be
stored in a public file storage repository. Users could download the build
artifacts directory from this repository. In fact, such a repository could also
be considered the Kernel Function Marketplace, and the source repository could
be a separate entity.

After building from source, we would then store the build artifacts into an
package file and sign it. The file would be signed by the L3AF Project.

### Multiple Versions

Regardless of whether the L3AF project builds programs from source or not,
Kernel Functions should use semantic versioning. The marketplace should then
host previous versions (in addition to the current version) in some reasonable
manner.

## Alternative to Hosting and Building Source Code

An alternative to the L3AF project hosting and building contributed source code
would be for contributors to submit or self-host a signed package containing
their Kernel Function and any documentation. The L3AF daemon, by default, would
only download and run Kernel Functions signed by trusted parties.

## Kernel Function Signing and Verification

There are two different layers of signing that should be discussed: the signing
of the kernel eBPF program and the signing of the Kernel Function package (i.e.,
an archive containing the built eBPF program and any associated userspace
programs).

### Signing and Verifying eBPF programs

There are efforts underway in the eBPF community for how to sign and verify
eBPF programs:

https://lore.kernel.org/bpf/20211203191844.69709-1-mcroce@linux.microsoft.com/
https://linuxplumbersconf.org/event/11/contributions/947/

L3AF will use the best practices that are established for signing and verifying
eBPF programs.

### Signing and Verifying the Kernel Function package

At a higher level, we also plan to sign and verify Kernel Function packages.

The package will be signed by its creator using a Private Enterprise Number
(PEN). L3AF will, by default, verify the package comes from a trusted source
before executing any files in the package.

# Kernel Function Marketplace of the Future

Future versions of the future could build on top of the foundation laid by the
initial versions.

## User Experience

A priority for future versions of the marketplace would be to improve the user
experience.

Some examples:
- Frontend website
- Searchable
- Rating system
- Reviews
- Buying and selling

## Closed Source Contributions

If a public Kernel Function Marketplace becomes popular, we can imagine that
some contributors may wish to monetize their Kernel Functions. In this case, we
would not be hosting and building the contributors source code and we would be 
hosting only a signed package containing their Kernel Function.

eBPF licensing information can be found below. The document discusses
"packaging BPF programs with user space applications."

https://www.kernel.org/doc/Documentation/bpf/bpf_licensing.rst
