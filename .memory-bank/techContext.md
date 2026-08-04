---
status: current
last-verified: 2026-08-04
owner: active-agent
source: repository evidence
---

# Tech context

## Stack

- Sampler 0.120.0 build framework on InvokeBuild, with Sampler.DscPipeline 0.3.0
  supplying the DSC-specific tasks; workflows are declared in `build.yaml`.
- Datum 0.41.0 for hierarchical configuration data, plus `Datum.ProtectedData`
  and `Datum.InvokeCommand` handlers; hierarchy declared in `source/Datum.yml`.
- Microsoft365DSC 1.25.730.1, driven through the composite resource modules
  `DscConfig.M365` 0.6.1-preview0001 and `DscConfig.Demo`.
- Pester 6.0.1 for the configuration-data and acceptance suites.
- GitVersion in `ContinuousDelivery` mode with `next-version: 0.0.1`.
- Azure DevOps YAML pipelines in `pipelines/` and `azure-pipelines.yml`;
  AutomatedLab-based provisioning scripts in `lab/`.

## Environment

- Windows. Verified locally on PowerShell 7.6.4 (Windows 10.0.26100).
- Build tasks are gated by `test7` and require PowerShell 7+. The
  `startConfiguration` and `testConfiguration` workflows are gated by `test5`
  and require Windows PowerShell 5.1.
- `SetPSModulePath` removes the personal and Program Files module paths during
  the build, so `Find-Module` and PowerShellGet are unavailable in a shell that
  has already run a build. Use a fresh shell or the PSGallery OData API.
- Dependencies resolve into `output/RequiredModules` (74 module folders at the
  time of writing). Pester is present as both `6.0.1` and a disabled `_5.7.1`.

## Constraints

- Module versions in `RequiredModules.psd1` are pinned. The Microsoft365DSC
  block is generated, not hand-edited, and must match the output of
  `Update-M365DSCDependencies -ValidateOnly`.
- The upgrade procedure documented inside `RequiredModules.psd1` is: bump the
  Microsoft365DSC version, restart the session to release module handles, delete
  `output/`, restore dependencies, regenerate the dependency block, then build.
- `-UseModuleFast` is commented out in the pipeline definitions.
- `PSDependOptions` sets `AllowPreRelease = $true`, so a `latest` pin resolves
  to prerelease versions.
- Never push to a git remote unless the user asks for it in the current turn.

## Dependency drift measured 2026-08-04

| Module | Pinned | PSGallery latest |
|---|---|---|
| Microsoft365DSC | 1.25.730.1 | 1.26.729.2 |
| DscConfig.M365 | 0.6.1-preview0001 | 0.6.1-preview0001 |
| DscConfig.Demo | `latest` (0.8.3 resolved) | 0.9.0-preview0002 |
| Sampler | `latest` (0.120.0 resolved) | 0.120.1-preview0002 |
| Sampler.DscPipeline | `latest` (0.3.0 resolved) | 0.3.0 |
| Datum | `latest` (0.41.0 resolved) | 0.42.0-preview0008 |
| Pester | `latest` (6.0.1 resolved) | 6.1.0-alpha2 |
| Microsoft.Graph.* | 2.28.0 | 2.39.0 |
| ExchangeOnlineManagement | 3.8.0 | 3.10.1 |
| MicrosoftTeams | 7.2.0 | 7.9.0 |
| PnP.PowerShell | 1.12.0 | 3.3.27-nightly |
| MSCloudLoginAssistant | 1.1.50 | 1.1.72 |
| Az.Accounts | 3.0.2 | 5.5.2 |
| DSCParser | 2.0.0.20 | 3.0.0.5 |
| ReverseDSC | 2.0.0.28 | 2.0.0.34 |

The Graph, Exchange, Teams, PnP, Az, DSCParser and ReverseDSC pins are dictated
by the Microsoft365DSC dependency manifest and must not be bumped on their own.

## Validation

- `.\build.ps1` — default `build` plus `pack` workflow; about five minutes.
- `.\build.ps1 -ResolveDependency -Tasks noop` — restore dependencies only.
- `.\build.ps1 -Tasks test` — VS Code task `test`.
- `.\build.ps1 -Tasks rsop` — compile RSOP without producing MOF files.
- Results land in `output/TestResults/*.xml`; transcripts in `output/Logs`.
