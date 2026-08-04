---
status: current
last-verified: 2026-08-04
owner: shared
source: repository evidence
---

# Project brief

## Purpose

Microsoft365DscWorkshop is a blueprint that puts Microsoft 365 and Entra ID
tenants under source control. It combines the build and configuration-data
patterns of [DscWorkshop](https://github.com/dsccommunity/DscWorkshop) with the
DSC resources of [Microsoft365DSC](https://microsoft365dsc.com/), so one
baseline can drive several tenants with controlled per-environment deviation.

## Scope

- In scope: the Datum YAML configuration hierarchy under `source/`; the Sampler
  build that produces RSOP, MOF, meta-MOF and compressed artifacts; Azure
  DevOps pipelines under `pipelines/`; tenant export tooling under `export/`;
  lab provisioning scripts under `lab/`; configuration-data and acceptance
  Pester suites under `tests/`; workshop material under `Summit2025/`.
- Out of scope: authoring Microsoft365DSC resources (upstream project);
  managing on-premises servers (covered by DscWorkshop); shipping
  `Microsoft365DscWorkshop` as a consumable PowerShell Gallery module — the
  repository is forked and adapted per adopter.

## Stakeholders

- DSC Community (`dsccommunity` GitHub organisation) — owning organisation.
- Raimund Andree — sole committer across the recorded history.
- Adopters who fork the repository to manage their own tenants.
- Workshop attendees using the `Summit2025/` material.

## Acceptance criteria

1. `.\build.ps1` completes green and emits RSOP, MOF, meta-MOF and compressed
   artifacts under `output/`.
2. The configuration-data and acceptance Pester suites report zero failures.
3. The pinned dependency set resolves from PSGallery, and the Microsoft365DSC
   dependency block matches `Update-M365DSCDependencies -ValidateOnly`.
4. The Azure DevOps build, test and push pipelines run against the Dev, Test
   and Prod tenants.
