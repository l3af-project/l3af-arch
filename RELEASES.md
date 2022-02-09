# Release Process

This section describes the release processes for tracking, preparing, and creating new L3AF releases. This includes information around the release cycles and guides for developers responsible for preparing upcoming stable releases.

## Active development

Active development is happening on the `main` branch, and a new version can be released from it in every 10-12 weeks.

## Release Tracking

Feature work for upcoming releases is tracked through GitHub Projects.

## Release Versions

We would be having a release version for every release. Minor releases are typically designated by incrementing 
the Y in the version format X.Y.Z. New patch releases for an existing stable version X.Y.Z are published by incrementing
the Z in the version format.

## Stable releases

Stable releases of L3AF include:

* Extended maintenance window (any version released in the last 6/12 months).
* Stability fixes backported from the `main` branch (anything that can result in a crash).
* Bugfixes, deemed worthwhile by the maintainers of stable releases.

### Post Release Activities

After each release, a tag with name ‘vX.Y.Z’, and a branch with name ‘release/vX.Y.Z’ can be created from the main branch. 
Merge permission to this branch would be given to the release manager and CI can be configured to execute tests on it.

### Backports

All other reliability fixes can be nominated for backporting to stable releases by L3AF code owners. 
The process of backporting can consist of the following steps:

- Changes nominated by the change author and/or members of the L3AF community are evaluated for backporting on a case-by-case basis
- These changes require approval from either the release manager of stable release or code owners.
- Once approved, these fixes can be backported from the `main` branch to an existing or previous stable branch by the code owners.

### Release management

Release managers of stable releases are responsible for approving and merging backports, tagging stable releases 
and sending announcements about them. 