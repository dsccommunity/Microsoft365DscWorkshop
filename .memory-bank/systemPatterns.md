---
status: current
last-verified: 2026-08-04
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
