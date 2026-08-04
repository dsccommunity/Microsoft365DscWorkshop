---
status: current
last-verified: 2026-08-04
owner: shared
source: repository evidence
---

# Product context

## Problem

Microsoft 365 and Entra ID tenant settings drift, are changed manually in the
portal without an audit trail, and are hard to keep in sync across Dev, Test and
Prod. Microsoft365DSC supplies the resources but no opinionated data model,
build, or release pipeline. This project supplies that missing layer.

## Users

- Platform and Microsoft 365 engineers who operate one or more tenants.
- Consultants who fork the blueprint for a customer tenant landscape.
- DSC community workshop attendees following the `Summit2025/` material.

## Core workflows

1. Edit YAML in the `source/` hierarchy, run the build, review the generated
   RSOP under `output/RSOP`, then commit.
2. The Azure DevOps build pipeline compiles artifacts; the push pipeline hands
   them to a build agent VM that enacts the configuration against its tenant.
3. The `export` workflow and the export pipeline read an existing tenant and
   convert its configuration to YAML to seed the hierarchy.
4. The `lab/` scripts provision app registrations, the Azure DevOps project and
   the agent VMs used by the workflows above.

## Experience goals

- One baseline for all tenants, with deliberate and visible deviation only.
- RSOP output that shows exactly what a tenant will receive before it is
  enacted.
- No plaintext secrets in the repository; `Datum.ProtectedData` handles
  encrypted values.
- A build that is reproducible from pinned module versions.
