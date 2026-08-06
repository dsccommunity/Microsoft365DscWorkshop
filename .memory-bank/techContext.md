---
status: current
last-verified: 2026-08-05
owner: active-agent
source: repository evidence
---

# Tech context

## Stack

- Sampler 0.120.0 build framework on InvokeBuild, with Sampler.DscPipeline 0.3.0
  supplying the DSC-specific tasks; workflows are declared in `build.yaml`.
- Datum 0.41.0 for hierarchical configuration data, plus `Datum.ProtectedData`
  and `Datum.InvokeCommand` handlers; hierarchy declared in `source/Datum.yml`.
- Microsoft365DSC 1.26.729.2, driven through the composite resource modules
  `DscConfig.M365` 0.7.0-preview0001 and `DscConfig.Demo`.
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
- Dependencies resolve into `output/RequiredModules` (51 module folders at the
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
- `Resolve-Dependency.psd1` must bootstrap `Microsoft.PowerShell.PSResourceGet`
  1.1 or later. 1.0.1 cannot parse a `PSResourceRepository.xml` that carries
  the `APIVersion="V2"` casing written by 1.1+ and aborts the restore with
  `Requested value 'V2' was not found`.
- Az.KeyVault is capped by the Az.Accounts version Microsoft365DSC pins.
  Az.Accounts 5.3.2 allows Az.KeyVault up to 6.4.2; 6.5.0 and later demand
  5.5.0 or newer.
- The `lab/` scripts call `Microsoft.Graph.*` cmdlets that Microsoft365DSC no
  longer pins. `RequiredModules.psd1` declares `Microsoft.Graph.Applications`,
  `Microsoft.Graph.Identity.DirectoryManagement`,
  `Microsoft.Graph.Identity.Governance` and `Microsoft.Graph.Users` outside the
  generated block. Their version must equal the generated
  `Microsoft.Graph.Authentication` pin, because every Graph SDK sub-module
  manifest requires that exact version of it.
- A restore fails with `Access to the path 'PowerShellYamlSerializer.dll' is
  denied` when any other PowerShell process holds `powershell-yaml`.
  `Resolve-Dependency.ps1` skips that module only when the restoring session
  itself has it loaded. Close the other sessions, or save the affected module
  on its own with `Save-PSResource -Path output\RequiredModules
  -TrustRepository`.
- Every pin must name a version that exists on the PowerShell Gallery. A pin to
  an unpublished version is skipped by the restore without failing it, and only
  surfaces later as a missing folder under `output/RequiredModules`.
- Never push to a git remote unless the user asks for it in the current turn.
- `Az.Accounts` `5.3.2` is built against MSAL `4.65`, `Microsoft.Graph.Authentication`
  `2.35.1` against MSAL `4.78`, and `ExchangeOnlineManagement` `3.9.2` ships
  `Microsoft.Identity.Client` `4.74.1` without the `Extensions.Msal` companion.
  Both versions are dictated by the Microsoft365DSC dependency block, so the
  conflict cannot be resolved by bumping a pin. Once Graph has loaded MSAL
  `4.78`, `Disconnect-AzAccount` fails with `Method not found: 'Void
  Microsoft.Identity.Client.Extensions.Msal.MsalCacheHelper.RegisterCache(Microsoft.Identity.Client.ITokenCache)'`.
  `Disconnect-M365Dsc` falls back to `Clear-AzContext -Scope Process`.

## Dependency state measured 2026-08-05

| Module | Pinned | PSGallery latest |
|---|---|---|
| Microsoft365DSC | 1.26.729.2 | 1.26.729.2 |
| DscConfig.M365 | 0.7.0-preview0001 | 0.7.0-preview0001 (0.6.1 stable) |
| DscConfig.Demo | `latest` (0.8.3 resolved) | 0.9.0-preview0002 |
| ComputerManagementDsc | 10.0.0 | 10.0.1-preview0003 |
| NetworkingDsc | 9.1.0 | 9.1.1-preview0001 |
| PSDesiredStateConfiguration | 2.0.8 | 2.0.8 |
| Az.KeyVault | 6.4.2 | 6.6.0 (needs Az.Accounts 5.5.2) |
| PSResourceGet (bootstrap) | 1.2.0 | 1.2.0 |
| Microsoft.Graph.Authentication | 2.35.1 | 2.39.0 |
| Microsoft.Graph.Applications | 2.35.1 | 2.39.0 |
| Microsoft.Graph.Identity.DirectoryManagement | 2.35.1 | 2.39.0 |
| Microsoft.Graph.Identity.Governance | 2.35.1 | 2.39.0 |
| Microsoft.Graph.Users | 2.35.1 | 2.39.0 |
| ExchangeOnlineManagement | 3.9.2 | 3.10.1 |
| MicrosoftTeams | 7.6.0 | 7.9.0 |
| PnP.PowerShell | 1.12.0 | 3.3.27-nightly |
| Az.Accounts | 5.3.2 | 5.5.2 |

The Graph, Exchange, Teams, PnP, Az, DSCParser and ReverseDSC pins are dictated
by the Microsoft365DSC dependency manifest and must not be bumped on their own.
The still-pinned DSC resources — xPSDesiredStateConfiguration 9.2.1, JeaDsc
0.7.2, WebAdministrationDsc 4.2.1, FileSystemDsc 1.1.1, SecurityPolicyDsc
2.10.0.0 and xDscDiagnostics 2.8.0 — are already at their newest stable
releases; only prereleases sit above them.

## Validation

- `.\build.ps1` — default `build` plus `pack` workflow; about five minutes.
- `.\build.ps1 -ResolveDependency -Tasks noop` — restore dependencies only.
- `.\build.ps1 -Tasks rsop` — `TestConfigData` plus `CompileDatumRsop`, the
  cheapest guard for a configuration-data change.
- `build.yaml` defines no `test` workflow, so the VS Code task `test`
  (`build.ps1 -AutoRestore -Tasks test`) aborts with `Missing task 'test'`.
- Results land in `output/TestResults/*.xml`; transcripts in `output/Logs`.
- The green baseline is 21 tasks, 0 errors, 0 warnings, with 129
  configuration-data tests and 12 acceptance tests, all passing. A run that
  reports 73 configuration-data tests means the `CompositeResources.Tests.ps1`
  container failed during discovery.
