# L3AFD Secure web API

## Overview

Walmart developed L3AF to simplify the management and orchestration of multiple eBPF programs in an enterprise
environment.

L3AF’s control plane consists of multiple components that work together to orchestrate eBPF programs:

- L3AF Daemon (L3AFD), which runs on each node where eBPF program runs. L3AFD reads configuration data and manages 
  the execution and monitoring of eBPF programs running on the node.
- Deployment HTTP APIs exposed by L3AFD, which a user calls to generate configuration data. This configuration data
  includes which eBPF programs will run, their execution order, and the configuration arguments for each eBPF program.
- A database and local key/value (KV) store that stores the configuration data.
- A datastore that stores eBPF program artifacts (e.g., byte code and/or native code).

When users want to deploy an eBPF program, they can use an app to call the L3AFD API with appropriate parameters.
This request would generate a new config (KV pair). Once L3AFD reads this new config, it orchestrates eBPF programs on
the host as per the defined parameters. If the user gives a set of eBPF programs, then L3AFD can orchestrate all of
them in the sequence that the user wanted (aka chaining).

## Need for secure web APIs

L3AFD currently uses the Go HTTP client to download the configured eBPF packages from a datastore (package repository).
However, this client does not support yet TLS, but we are investigating how best to support TLS. In the open-source
world, users will presumably expect to be able to use TLS in this situation. This is also an early step toward using
a secure eBPF Package Repository (https://github.com/l3af-project/l3afd/issues/2).

L3AFD has an HTTP API that can be used to configure the eBPF programs. However, this API only supports HTTP.
This works for a use case where the L3AFD API is called only from the localhost, but this is probably unintuitive.
In the future, we would like to come up with service that can call the L3AFD APIs remotely. For this, we could leverage
mTLS for a mutually secure connection between the client and server. Also, new open-source adopters of L3AF will presumably
want to avoid calling the L3AFD API locally on each node (https://github.com/l3af-project/l3afd/issues/4).

## Types of certificates are supported

The TLS protocol aims primarily to provide cryptography, including privacy (confidentiality), integrity, and
authenticity through certificates, between L3AFD and client's communication. These certificates can be issued by a
third-party trusted authority (i.e., IdenTrust, DigiCert, Sectigo, etc), and we can create self-signed certificates
using tools like ```openssl```.

This completely depends on the users, whether to use Trusted CA certificates or self-signed certificates. L3AF will not 
provide any certificates.

## L3AF deployment scenarios

L3AF could be running in two scenarios, users can use L3AF in secure enterprise private networks and in public networks.
In the case of a private network, L3AFD and clients will be communicating with each other over a network that is normally
protected by vpn or PCI (Payment Card Information), and hence some may not consider it essential to enable mTLS in this
case, although the current industry trend and best practice is to consider it essential even on private networks, which
trend uses the [Zero trust security model](https://en.wikipedia.org/wiki/Zero_trust_security_model).

However, in the case of a public network, clients will be communicating with L3AFD over insecure networks. L3AF wants to
secure its endpoints using industry's best standard available solutions. This can be configured from l3afd’s config file.

## Enabling mTLS for L3AFD

L3AFD (L3AF Daemon) will require a set of root certificates (root.crt and root.key) and a pair of server certificates
(server.crt and server.key) to accept remote connections. L3AFD will check for these certificates, and in case these are
not found, L3AFD will stop with error ```certificates are not found```.

The client will require a pair of client certificates (client.crt and client.key), generated from the same root
certificates from which the server certificates have been generated, and the public root certificate (root.crt) to
communicate with L3AFD.

Process to enable mTLS 
- [Provision of Certificates](#provision-of-certificates)
- [Location of Certificates](#location-of-certificates)
- [Enable mTLS](#enabling-mtls)

### Provision of Certificates

As mentioned before, users can use already pre-existing certificates. L3AF will not provide any certificates.

### Location of Certificates

The default location for the certificates and the path can also be changed through a l3afd configuration option
in cases where the user would like to use a custom location.

The user will have to place the root certificates and the server certificates in the configured directory path before
starting L3AFD.

### Enabling mTLS

A flag will be provided in l3afd.cfg which enables mTLS by default. L3AFD will not accept remote connections
without TLS by default.

## Minimum TLS version

The TLS versions popularly supported in the market are v1.2 and v1.3. L3AF can support v1.3 by default and require configuration
to allow downgrading security.

## L3AFD Web API Listening Interface

L3AFD can be configured to listen on IP addresses / interfaces other than localhost.
There could be an additional check to only accept traffic from the specified FQDN (Host header) or SNI if TLS.

## Monitoring of certificates

L3AFD will be monitoring for expiration of the certificates on regular basis (e.g., every 24 hours) and it will start
logging warnings before a certain period (30 days) of expiration date. If the certificates are not renewed before
expiration, L3AFD will stop with error ```certificates are expired, replace new pair of certificates```.
It is users' responsibility to replace old certificates with new pair certificates. L3AFD loads the new
certificates automatically, and it does not require a restart.

L3AFD can also expose metrics for the certificate expiration status and certificate errors.

## Token-based authentication

In this approach OAuth2 token used for authenticating the client. Here, clients should acquire tokens from the identity
management service. Every request will have a metadata component which carries the token. L3AFD will verify the token with
the configured identity management service and if the token is valid it will then accept the request.

## Authorization

Authorization is a security mechanism that verifies the clients have sufficient permissions to perform any CRUD actions
on config resources. RBAC determines client privileges to update the configs on the node and enables access controls
based on granted roles. Initially there will admin and user roles.
- Admin - Full permission to create, update, read, and delete any configuration element through the API
- Read-Only - Permission to read configuration elements through the API
