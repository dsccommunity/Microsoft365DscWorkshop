---
status: current
last-verified: 2026-08-17
owner: active-agent
source: repository evidence
---

# Progress

## Current status

The build is green on `feature/update2608` with the dependency set updated to
August 2026 levels.

## Recent milestones

- 2026-08-17 Fixed `.\build.ps1` failing in `TestConfigData` with Pester 6.1.0's
  `A 'break' or 'continue' statement ... escaped from your code`. That message is
  a misdiagnosis: Pester 6.1.0 throws it from a `finally` over any terminating
  error in user code. The real error was `Import-Module -Name Az.Accounts
  -RequiredVersion 5.3.2 -Force` in the top-level `BeforeAll` of
  `tests/ConfigData/AzHelpers.Tests.ps1` dying with `Assembly with same name is
  already loaded`, because `.build/ConfigDataPreparation.ps1` had already loaded
  `Az.Accounts 5.5.2` and `Az.Resources 9.0.1` into the build session. The
  `BeforeAll` now imports a module only when no module of that name is loaded,
  and reads the version to pin from `RequiredModules.psd1` rather than repeating
  it.
- 2026-08-07 Fixed the `push` pipeline failing in `Deploy DSC Configuration` with
  `MSFT_SPOAccessControlSettings ... The current connection holds no SharePoint
  context`. The Dev tenant has no SharePoint Online provisioned — neither
  `MngEnvMCAP167509.sharepoint.com` nor its `-admin` host resolves — so
  `Connect-PnPOnline` can never build a SharePoint context. Added the
  per-environment `HasSharePointOnline` setting as the counterpart of
  `HasExchangeOnline`: `source/Datum.yml` swaps both SharePoint layers for the
  new empty `source/1-AllTenantsConfig/SharePointDisabled` layer,
  `.build/Export/ExportTenantData.ps1` skips the `SPO*` components, and a
  configuration data test guards the mechanism.
- 2026-08-07 Fixed the `push` pipeline failing in `Build DSC Artifacts` with
  `Detected characters in arguments that may not be executed correctly by the
  shell`. The `Enable shell tasks arguments validation` setting rejects the
  environment filter script block in the `arguments` input of `PowerShell@2`,
  and backtick escaping would turn it into a literal string, so
  `pipelines/buildTemplate.yml` now calls `./build.ps1` from an inline `script`
  for both `Build DSC Artifacts` and the disabled `Pack DSC Artifacts`.
- 2026-08-06 Fixed the export pipeline stage failing in `Publish Exported Data`
  with `Path does not exist: ...\output\Export`. The cause was two matching
  export applications: `source/Global/Azure.yml` still carried the sample
  identity `<Name of your Application of Managed Identity>` with
  `IsExportApplication: true` next to `M365DscExportApplication`, so
  `.build/Export/ExportTenantData.ps1` stopped before creating the folder while
  `continueOnError: true` hid it. The placeholder was removed, the task ignores
  `<...>` placeholders and counts matches instead of testing for `$null`, the
  export step lost `continueOnError`, and a configuration data test asserts one
  export application per environment.
- 2026-08-06 Fixed `lab/31 Agent Setup.ps1` failing to download the Azure
  Pipelines agent from the retired CDN `vstsagentpackage.azureedge.net`. All
  build agent software now comes from Chocolatey — `vscode`,
  `vscode-powershell`, `git`, `notepadplusplus` and `azure-pipelines-agent` —
  which also removed the script's need for the Azure lab sources share and with
  it the failing hard-coded `C:\AL\AzureLabSources.ps1` call. Two AST-based
  regression cases guard both defects.
- 2026-08-06 Fixed `lab/30 Create Agent VMs.ps1` registering a superfluous Entra
  application next to the build agent's user-assigned managed identity, which
  surfaced as a `404` from `Update-MgApplication`. It now calls
  `New-M365DscIdentity -OnlyServicePrincipals`, and `Remove-M365DscIdentity`
  skips `Remove-MgApplication` for an identity without an application. The
  leftover application was removed from the Dev tenant.
- 2026-08-06 Fixed the post-deployment validation of `Install-Lab` reporting a
  false `Lab deployment seems to have failed`. `AutomatedLabTest` 5.61.4 cannot
  be discovered under Pester 6, so `lab/00 Prep.ps1` pins Pester `5.7.1` and
  `lab/30` imports it before `Install-Lab`.
- 2026-08-06 Fixed `lab/30`, `lab/31`, `lab/88`, `lab/89` and `lab/97` stopping
  with `is not licensed for Exchange Online` on an environment configured with
  `HasExchangeOnline: false`. They called `Connect-M365Dsc` without the
  `SkipExchangeOnline` switch although none of them uses Exchange Online; all
  five now derive it from the environment, a Pester case guards every `lab/`
  script that connects, and both messages naming the removed `ExchangeConfigSet`
  node property were corrected.
- 2026-08-06 Fixed `lab/20 Configure AzDo Project.ps1` aborting the pipeline
  commit with `fatal: ..\pipelines\build.yml ... is outside repository` when
  started from the repository root. The git calls now run with
  `git -C <repository root>` and consume the repository-root relative paths of
  `git diff --name-only` unchanged; `lab/31 Agent Setup.ps1` lost the same `..`
  assumption.
- 2026-08-06 Fixed `Disconnect-AzAccount` failing with `Method not found:
  MsalCacheHelper.RegisterCache(ITokenCache)` in every `lab/` script. The MSAL
  versions of `Az.Accounts` and `Microsoft.Graph.Authentication` are both
  dictated by the Microsoft365DSC dependency block, so `Disconnect-M365Dsc`
  falls back to `Clear-AzContext -Scope Process` for that specific error and
  still surfaces any other one.
- 2026-08-06 Added support for tenants without an Exchange Online license. The
  user-maintained `HasExchangeOnline` setting per environment is the single
  switch: the lab scripts skip their Exchange Online work, `Connect-M365Dsc`
  validates the tenant against it with the new
  `Test-M365DscExchangeOnlineLicense` before any prep work, `source/Datum.yml`
  swaps both Exchange layers for an empty `ExchangeDisabled` layer so no `cEXO*`
  configuration is compiled, and the export skips the `EXO*` components.
- 2026-08-06 Fixed `Remove-M365DscIdentityPermission` failing to remove the
  subscription `Owner` assignment on the Azure MFA claims challenge. The retry
  from `Add-M365DscIdentityPermission` moved into the shared
  `Resolve-M365DscAzureMfaChallenge`, `Remove-AzRoleAssignment` now runs with
  `-ErrorAction Stop`, and the false success message was corrected. Three Pester
  tests cover both helper branches and the removal retry.
- 2026-08-05 Fixed `Connect-M365DscAzure` selecting the Azure account's default
  subscription during application-secret or certificate authentication. It now
  forwards the configured subscription to `Connect-AzAccount`; an offline
  regression test covers both service-principal paths. The live connection test
  selects `<dev-subscription-name>` and passes all service-context validation.
- 2026-08-05 Fixed the placeholder identity in `lab/10 Setup App
  Registrations.ps1`: unfilled `<...>` names are skipped, `IsManagedIdentity` is
  honoured through `-OnlyServicePrincipals`, and the placeholder was removed
  from `source/Global/Azure.yml`. Also fixed `-OnlyServicePrincipals -PassThru`
  and added an MFA claims-challenge retry around `New-AzRoleAssignment`.
- 2026-08-05 Fixed `lab/10 Setup App Registrations.ps1` failing with `The term
  'New-M365DSCSelfSignedCertificate' is not recognized`: `lab/AzHelpers.psm1`
  now imports `lab/CertHelpers.psm1` instead of relying on the `InitLab` task.
- 2026-08-05 Fixed `lab/10 Setup App Registrations.ps1` failing with `The term
  'Get-MgApplication' is not recognized`: Microsoft365DSC `1.26.729.2` stopped
  pinning the granular `Microsoft.Graph.*` modules the lab scripts call.
  `RequiredModules.psd1` now declares the four they need at `2.35.1`.
- 2026-08-05 Diagnosed the `AADSTS500014` failure of
  `lab/10 Setup App Registrations.ps1` as a lapsed Microsoft 365 subscription in
  the Dev tenant, not a code defect. No subscribed SKUs, all 88 assigned plans
  `Deleted`, and every workload service principal disabled. Not fixable from
  this repository.
- 2026-08-05 Fixed `lab/10 Setup App Registrations.ps1`: it never imported
  `AzHelpers.psm1` and relied on another script having loaded the module in the
  same session.
- 2026-08-05 Fixed `lab/10 Setup App Registrations.ps1`: `Connect-M365Dsc` in
  `lab/AzHelpers.psm1` called `Sync-M365DSCParameter`, which Microsoft365DSC
  `1.26.729.2` no longer ships. Replaced it with the local
  `Select-M365DscCommandParameter`.
- 2026-08-05 Fixed `lab/00 Prep.ps1` for a session that has already run
  `build.ps1`: `Set_PSModulePath` strips the CurrentUser and AllUsers module
  scopes, so AutomatedLab was reinstalled and its commands stayed unrecognized.
  Added `Restore-DefaultModulePath`.
- 2026-08-05 Fixed `lab/00 Prep.ps1`: an `Az.Accounts` 5.5.1 copy in the
  CurrentUser scope shadowed 5.5.2 in AllUsers, so
  `Test-LabAzureModuleAvailability` could never succeed. Added an elevation
  guard, a prerelease-aware installed-version check, the `Resolve-ShadowedModule`
  cleanup and comment-based help; repinned AutomatedLab to `5.61.0`.
- 2026-08-05 Fixed the build: `DscConfig.M365` was pinned to the unpublished
  version `0.7.9-preview0001`, so the module never restored and
  `TestConfigData` failed during Pester discovery. Repinned to
  `0.7.0-preview0001`; build green again, test counts unchanged.
- 2026-08-04 Dependencies updated: Microsoft365DSC `1.26.729.2`, the
  regenerated 14-entry dependency block, ComputerManagementDsc `10.0.0`,
  NetworkingDsc `9.1.0`, PSDesiredStateConfiguration `2.0.8`, Az.KeyVault
  `6.4.2` and PSResourceGet `1.2.0`. Build green, test counts unchanged.
- 2026-08-04 Memory Bank base created.
- 2026-08-04 Full build verified green: 21 tasks, 0 errors, 0 warnings.
- 2026-08-04 `017fc2a` fixed the `TestConfigData` task for Pester 6.
- 2025-08-04 `3df7af7`, the last commit before the dormant period.
- 2025-08-02 Export guidance for Azure DevOps added; `-UseModuleFast` disabled
  across the pipeline definitions.

## Stable capabilities

- Datum hierarchy loads, and RSOP compiles for the Dev, Test and Prod nodes.
- Root configuration and meta-MOF compile for all three environments.
- Artifact packing produces checksums, compressed modules and artifact
  collections.
- Configuration-data (129) and acceptance (12) Pester suites pass.
- Tenant export tooling and AutomatedLab provisioning scripts are present, but
  are unverified since the dormant period.

## Open work

### Tenant-readiness findings, 2026-08-04

- The compiled Dev MOF carries 23 Microsoft365DSC instances built from demo
  data, including `MSFT_AADSecurityDefaults`, `MSFT_AADAuthorizationPolicy`,
  `MSFT_SPOTenantSettings`, `MSFT_SPOAccessControlSettings`, two
  `MSFT_EXOTransportRule`, both EXO connectors and two `MSFT_EXORemoteDomain`
  pointing at `contoso.com`. Trim `Configurations.yml` before the first enact.
  Superseded for Dev on 2026-08-07: `HasExchangeOnline: false` and
  `HasSharePointOnline: false` reduce the Dev MOF to the six AAD and tagging
  instances. Test and Prod are untouched.
- Unresolved placeholders compile into the MOF without failing the build:
  `TenantId = "<TenantFQDN>"` 22 times and `<AutoGeneratedLater>` for one
  `ApplicationId` and one `CertificateThumbprint`. No test guards against this.
- The three `cAADRoleSetting.yml` files hardcode
  `ApplicationId: a86901b1-da9c-4abd-8f53-b90977ab9493`, an app ID from a
  foreign tenant. `cAADRoleSetting` is enacted in Test and Prod.
- `source/Datum.yml` protects the app secret with `PlainTextPassword:
  SomeSecret`, committed to the repo. `docs/temp/EncryptingSecrets.md` explains
  the certificate alternative but imports `lab/Helpers.psm1`, which does not
  exist; the real modules are `AzHelpers.psm1`, `CertHelpers.psm1` and
  `M365DscHelpers.psm1`.
- `lab/10 Setup App Registrations.ps1` prints the generated secret to the
  console, then commits and pushes `source/Global/Azure.yml` to `origin`.
  `source/Global/ProjectSettings.yml` holds a plaintext Azure DevOps PAT and a
  build-agent password.
- `Add-M365DscIdentityPermission` grants the permission set compiled from every
  Microsoft365DSC resource, adds `M365DscSetupApplication` to Global
  Administrator and assigns subscription Owner.
- 20 of the 23 M365 instances set `ManagedIdentity = True`, so enactment only
  authenticates on an Azure VM that carries the identity.
- `pipelines/push.yml` applies through `startDscTemplate` before
  `testDscTemplate` runs; `pipelines/test.yml` is the dry-run entry point.

### Carried over

- Decide whether to move `DscConfig.Demo` forward to its preview release.
- Settle the Pester policy: 6.0.1 is resolved and 5.7.1 sits disabled as
  `_5.7.1` in `output/RequiredModules`.
- Re-verify the Azure DevOps pipelines and the `lab/` scripts against current
  Azure and Microsoft 365 APIs.
