# Ideas for Simplifying eBPF program chaining

The purpose of this document is to discuss 
1) why we do eBPF program chaining, 
2) how chaining is implemented currently in L3AF, and 
3) ideas and plans for chaining enhancements.

We encourage the open source community to be involved with all phases of planning and implementation.

# Introduction

## What is eBPF program chaining

eBPF program chaining is the procedure of calling multiple eBPF programs in a sequence. In the case of network eBPF programs, only a single eBPF program can be attached to the network interface for each type (i.e., TC and XDP). We can, however, sequentially execute multiple eBPF programs per type by having eBPF programs call the next program in the chain.

## Why do we chain eBPF programs?

This is maybe the most common question we get about L3AFD. To understand the answer, it's important to understand one of the core philosophies of L3AF: L3AF is a platform to orchestrate and compose multiple, independent eBPF programs. We believe that eBPF users can benefit from the development and open distribution of modular eBPF programs. In this respect, we embrace the Unix philosophy of “write programs that do one thing and do it well.” Our vision is that the L3AF team, open-source community, and other businesses will develop independent eBPF programs that will be shared in a “eBPF Package Repository.” Users can then download a selection of signed eBPF programs and orchestrate them to solve their unique business needs.

As an example, in one datacenter you may want to run this chain of programs:

`rate limiter` -> `connection limiter` -> `traffic mirroring`

However, in another datacenter, you may want to this chain:

`rate limiter` -> `connection limiter` -> `load balancer`

Chaining together eBPF programs is the key feature that empowers users to compose different, independent programs together to solve those unique business needs.

## How is chaining done today?

Chaining in L3AF today is done using the `bpf_tail_call` BPF helper function (see `bpf-helpers(7)`). The `bpf_tail_call` function is called at the end of each eBPF kernel program. However, for chaining to be most useful, we must not hard code the next program in the chain; we want that to be dynamic so that programs in the chain can be added, removed, or reordered on-the-fly. This dynamic chaining is accomplished by using eBPF maps to store and retrieve the next eBPF program file descriptor (FD) in the chain. In L3AF, the order of operations goes like this: 1) each eBPF program creates a map where the FD of the next program should be stored, 2) the next program in the chain writes its FD to the map of the previous eBPF program, and 3) a previous kernel eBPF program runs and before finishing reads the FD to the next kernel eBPF program and executes it with a `bpf_tail_call`.

Here is a visual representation:

![L3AF_eBPF_chaining](https://user-images.githubusercontent.com/146526/140865148-995a0578-eaef-456c-832b-83ababa6484e.png)

# Problem Statement

Our current chaining approach is functional (and similar approaches are used in other projects). However, there is one issue that puts the current approach at odds with our long term vision for truly independent and modular eBPF programs.

The problem with the current approach is that it requires each eBPF program be aware that it is part of a chain of programs. More specifically, each eBPF program must contain a nontrivial amount of logic to manage itself in the chain and also call the next program in the chain.

For example, the userspace eBPF program must write its FD to the previous eBPF program's map:

```c
/* Get the previous program's map fd in the chain */
int prev_prog_map_fd = bpf_obj_get(prev_prog_map);
if (prev_prog_map_fd < 0) {
    log_err("Failed to fetch previous xdp function in the chain");
    exit(EXIT_FAILURE);
}
/* Update current prog fd in the last prog map fd,
 * so it can chain the current one */
if(bpf_map_update_elem(prev_prog_map_fd, &pkey, &(prog_fd[0]), 0)) {
    log_err("Failed to update prog fd in the chain");
    exit(EXIT_FAILURE);
}
```

And the kernel eBPF program must do perform the `bpf_tail_call` to the next program:

```c
/* Maintains the prog fd of the next XDP program in the chain */
struct bpf_map_def SEC("maps") xdp_rl_ingress_next_prog = {
        .type           = BPF_MAP_TYPE_PROG_ARRAY,
        .key_size       = sizeof(int),
        .value_size     = sizeof(int),
        .max_entries    = 1
};

// ...

bpf_tail_call(ctx, &xdp_rl_ingress_next_prog, 0);
```

In addition to these snippets, there is other chain-related code and state that are required for each ePBF program. Ideally, we want to move all chain related policy and code up the stack and into L3AFD, such that the individual eBPF programs don't require any code specific to chaining. Doing so would accomplish the following project goals:

1. eBPF programs become truly independent and modular
2. Developers of eBPF programs don't need to implement any "special" logic or boilerplate in their program
3. The eBPF Package Repository becomes an easier place to contribute to because eBPF programs don't require chaining logic

# Proposed Solution

## Kernel >= 5.10

### XDP

As of Linux kernel 5.10, the kernel and libxdp have the ability to chain eBPF programs using a multi-program "dispatcher." A formal specification for doing so is found [here](https://github.com/xdp-project/xdp-tools/blob/master/lib/libxdp/protocol.org). This would allow for L3AF to completely manage the chaining of eBPF programs that do not require any chain-specific logic themselves. However, in order for this to happen, a Go libxdp implementation is needed.

Visually, this proposed solution would look like this:

![L3AF_xdp_dispatcher_chaining](https://user-images.githubusercontent.com/146526/140865168-f51a40a9-d664-443d-ada1-18f1348311fb.png)

L3AFD would interface directly with libxdp to set the execution order of the eBPF kernel programs.

Userspace eBPF programs could still be run to interface with their respective kernel programs.  We would like to migrate these userspace programs from C to Go (now that there are good Go eBPF libraries available), but that migration is beyond the scope of this document.

### TC

Similar to XDP, TC already has its own mechanisms for chaining TC eBPF programs without the need for chain-specific logic in the eBPF programs. In fact, using these capabilities does not require Linux Kernel >= 5.10 (presumably, the TC chaining capabilities have been available much longer). However, we believe it would make sense to migrate away from `bpf_tail_call` at the same time for both TC and XDP. The reason for this belief is that one benefit of `bpf_tail_call` is that it works the same for both TC and XDP--if we're going to use it for one, we might as well use it for the other; we don't reap the true benefit unless we completely remove the need for chain-specific logic in all eBPF programs.

The TC tooling is relatively complex and more testing is needed to confirm the exact TC-based approach, but chaining should look like this:

```bash
# tc filter replace dev em1 ingress prio 1 handle 1 bpf da obj prog1.o
# tc filter replace dev em1 ingress prio 2 handle 1 bpf da obj prog2.o
```

(Ideally we would call into a library instead of running `tc` directly)

## Kernels < 5.10

For kernels that do not support the libxdp dispatcher, we plan to continue to use `bpf_tail_call` and simply phase it out over time. However, there are some improvements we could make to this existing approach:

1. Automate the injection of the necessary boilerplate code for chaining via `bpf_tail_call`.
2. Consolidate our usage of multiple chaining maps into a single map (per eBPF program type) that can be replaced atomically. We believe this is the approach Cilium uses, for example.

## Phase 1 Solution -

Decouple the chaining logic from eBPF programs.

![L3AF_decouple_chaining](https://user-images.githubusercontent.com/7508744/216295926-e05d55ec-33d8-48b6-8783-b5b02a28f3da.png)

This approach will work for program type XDP and TC with cross-platform support. This will not support atomic updates.
