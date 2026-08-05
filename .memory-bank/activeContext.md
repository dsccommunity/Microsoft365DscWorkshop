---
status: current
last-verified: 2026-08-05
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

The build is green again after correcting the `DscConfig.M365` pin. Work happens
on the branch `feature/update2608`; the user asked that changes stay
uncommitted.

## Evidence

- `RequiredModules.psd1` pinned `DscConfig.M365` `0.7.9-preview0001`, a version
  that is not published on the PowerShell Gallery. The newest published releases
  are `0.6.1` (stable) and `0.7.0-preview0001`, both from 2026-08-04.
- The restore skipped the module without failing, leaving 51 folders in
  `output/RequiredModules` and no `DscConfig.M365`. `TestConfigData` then failed
  during Pester discovery with `Cannot find path ...\DscConfig.M365`, because
  `tests/ConfigData/CompositeResources.Tests.ps1` resolves every entry of
  `build.yaml`'s `Sampler.DscPipeline.DscCompositeResourceModules`. Only 73 of
  129 configuration-data tests ran.
- The pin is now `0.7.0-preview0001`; PSResourceGet stores it as
  `output/RequiredModules/DscConfig.M365/0.7.0`.
- `.\build.ps1` after the fix: `Build succeeded. 21 tasks, 0 errors, 0 warnings`
  in 5 minutes 31 seconds, with 129 configuration-data tests and 12 acceptance
  tests, both 0 failures.
- The composites do not name resource properties themselves, so the
  `Eligibility*` rename in the three `cAADRoleSetting.yml` files stays correct
  under `DscConfig.M365` `0.7.0-preview0001`.
- The restore logs `Cannot remove package path` for modules that another
  PowerShell session holds open (`powershell-yaml`, `ProtectedData`,
  `Az.KeyVault`). Those modules are already at the pinned version, so the
  restore continues and the build is unaffected.

## Earlier evidence

- `RequiredModules.psd1` now pins Microsoft365DSC `1.26.729.2`,
  ComputerManagementDsc `10.0.0`, NetworkingDsc `9.1.0`,
  PSDesiredStateConfiguration `2.0.8` and Az.KeyVault `6.4.2`.
- The regenerated Microsoft365DSC dependency block has 14 entries instead of
  38. The release replaced every granular `Microsoft.Graph.*` pin with
  `Microsoft.Graph.Authentication` `2.35.1`, dropped
  `Microsoft.PowerApps.Administration.PowerShell`, and added `Az.Subscription`,
  `Az.Security` and `PSParallelPipeline`.
- `Resolve-Dependency.psd1` now bootstraps `Microsoft.PowerShell.PSResourceGet`
  `1.2.0`. Version `1.0.1` aborted the restore with `Requested value 'V2' was
  not found` because it cannot parse a `PSResourceRepository.xml` written by
  `1.1` or later.
- Microsoft365DSC `1.26.729.2` renamed the `AADRoleSetting` properties
  `Elegibility*` to `Eligibility*`. The three `cAADRoleSetting.yml` files under
  `source/2-EnvironmentConfig` were updated; without that the
  `CompileRootConfiguration` task fails with `InvalidInstanceProperty`.
- `.\build.ps1` after the update: `Build succeeded. 21 tasks, 0 errors, 0
  warnings` in 4 minutes 27 seconds. Test results match the pre-update
  baseline exactly: 129 configuration-data tests and 12 acceptance tests, both
  with 0 failures.

## Next step

Decide whether to move `DscConfig.Demo` to its preview release, and re-verify
the Azure DevOps pipelines and the `lab/` scripts against current Azure and
Microsoft 365 APIs.
