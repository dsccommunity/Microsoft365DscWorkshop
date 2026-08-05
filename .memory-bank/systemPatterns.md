---
status: current
last-verified: 2026-08-05
owner: active-agent
source: repository evidence
---

# System patterns

## Architecture

Configuration data lives in `source/` as a Datum hierarchy resolved by
`source/Datum.yml`. Node definitions sit under `source/BuildAgents/<Environment>`
for the `Dev`, `Test` and `Prod` environments; each node represents the build
agent that enacts one tenant. Resolution walks from the node, through
`2-EnvironmentConfig/<Environment>` per service area (AzureAd, Exchange,
SharePoint, Purview), down to the `1-AllTenantsConfig` baseline and the
`0-DscConfiguration/LcmConfiguration` defaults. `source/Global` holds Azure and
project settings.

The Sampler build in `build.yaml` runs `Clean`, `ModuleCleanup`,
`Build_Module_ModuleBuilder`, `LoadDatumConfigData`, `ConfigDataPreparation`,
`TestConfigData`, `CompileDatumRsop`, `Set_PSModulePath`, `TestDscResources`,
`CompileRootConfiguration` and `CompileRootMetaMof`, then packs checksums,
compressed modules and artifacts and runs `TestBuildAcceptance`. The root
configuration imports the composite modules `PSDesiredStateConfiguration`,
`DscConfig.M365` and `DscConfig.Demo`.

Azure DevOps pipelines in `pipelines/` cover build, test, push, reapply and
export; `azure-pipelines.yml` is the entry point. The `lab/` scripts provision
app registrations, the Azure DevOps project and the agent VMs.

## Decisions

### Decision 1: Use the canonical Memory Bank base

- Choice: Keep durable project context in .memory-bank.
- Rationale: Preserve evidence-backed context across sessions.

### Decision 2: Model tenants as Datum nodes named after their build agents

- Choice: Node definitions live under `source/BuildAgents/<Environment>` and the
  first entry of `ResolutionPrecedence` is the node itself.
- Rationale: Push mode enacts each tenant from a dedicated agent VM, so agent
  and tenant are one-to-one and a single identity serves both roles.

### Decision 3: Pin the Microsoft365DSC dependency block instead of tracking it

- Choice: `RequiredModules.psd1` carries an explicit, generated list of
  Microsoft365DSC's own dependencies at exact versions.
- Rationale: Microsoft365DSC is sensitive to the versions of the Graph,
  Exchange, Teams and PnP modules; floating those pins has broken builds before
  (see commit `e1ced29`, which reverted versions because of a Microsoft365DSC
  issue).

### Decision 4: Look node definitions up through `AllNodes`

- Choice: `tests/ConfigData/ConfigData.Tests.ps1` filters discovered YAML files
  against `$configurationData.AllNodes.Name`, and only builds role test cases
  when role definition files exist.
- Rationale: Pester 6 rejects an empty `-TestCases` collection during discovery;
  the previous lookup used a non-existent `BuildAgents` key and produced one.
  Recorded in the changelog under `[Unreleased] / Fixed`.

### Decision 5: Read the dependency block from the Microsoft365DSC package

- Choice: Regenerate the generated block in `RequiredModules.psd1` by extracting
  `Dependencies/Manifest.psd1` from the Microsoft365DSC `.nupkg` on the gallery,
  rather than restoring first and running `Update-M365DSCDependencies
  -ValidateOnly` afterwards.
- Rationale: The documented procedure needs two full restores because the block
  is only correct after the first one. Reading the manifest out of the package
  produces the same list up front, so a single restore suffices.

### Decision 6: Treat a Microsoft365DSC bump as a config-data breaking change

- Choice: After bumping Microsoft365DSC, compile and read the
  `InvalidInstanceProperty` errors from `CompileRootConfiguration`, then rename
  the affected properties in `source/`.
- Rationale: Microsoft365DSC renames resource properties between releases.
  1.26.729.2 corrected `AADRoleSetting`'s `Elegibility*` to `Eligibility*`,
  which broke the three `cAADRoleSetting.yml` files. The composite splats config
  data straight onto the resource, so the compiler is the only place the
  mismatch surfaces.

### Decision 7: Confirm a pinned version exists before restoring

- Choice: Check the PowerShell Gallery for the exact version before changing a
  pin in `RequiredModules.psd1`, and confirm the folder afterwards under
  `output/RequiredModules`.
- Rationale: `Resolve-Dependency` skips a pin that names an unpublished version
  without failing the restore. `DscConfig.M365` `0.7.9-preview0001` does not
  exist, and the miss only surfaced two tasks later as a Pester discovery error
  in `CompositeResources.Tests.ps1`, which resolves every composite module
  listed in `build.yaml`.
