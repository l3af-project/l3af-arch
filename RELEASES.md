# Release Process

This section describes the release processes for tracking, preparing, and creating new L3AF releases. This includes information around the release cycles and guides for developers responsible for preparing upcoming stable releases.

## Active Development

Active development is happening on the `main` branch, and a new version can be released from it every 10-12 weeks.

## Release Tracking

Feature work for upcoming releases is tracked through [GitHub Projects](https://github.com/l3af-project/l3af-arch/projects?type=beta).

## Release Versioning

We will follow [Semantic Versioning 2.0](https://semver.org/).

### Post Release Activities

After each release, a tag with name ‘X.Y.Z’, and a branch with name ‘X.Y.Z’ is created from the main branch.
Merge permission to this branch will be given to the release manager and CI will be configured to execute tests on it.

## Stable Releases

Stable releases of L3AF include:

* Maintenance window (any version released in the last 6 to 12 months).
* Stability fixes backported from the `main` branch (anything that can result in a crash).
* Bugfixes, deemed worthwhile by the maintainers.

### Backports

The process of backporting can consist of the following steps:

- Changes nominated by the change author and/or members of the L3AF community are evaluated for backporting on a case-by-case basis
- These changes require approval from both the release manager of the stable release and from the relevant code owners.
- Once approved, these fixes can be backported from the `main` branch to an existing or previous stable branch by the branch's release manager.

### Release Management

Release managers of stable releases are responsible for approving and merging backports, tagging stable releases 
and sending announcements about them.
