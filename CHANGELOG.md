# Changelog for DscPipeline

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial Upload
- Support tenants without an Exchange Online license. The new per-environment
  setting `HasExchangeOnline` in `source/Global/Azure.yml` is maintained by the
  user and controls the Exchange Online prep work. `Connect-M365Dsc` gained a
  `SkipExchangeOnline` switch and validates the tenant entitlement with the new
  `Test-M365DscExchangeOnlineLicense` before connecting, so a tenant that
  contradicts the setting fails with an actionable error instead of an
  `AADSTS500014`. `New-M365DscIdentity`, `Get-M365DscIdentity`,
  `Remove-M365DscIdentity`, `Add-M365DscIdentityPermission` and
  `Remove-M365DscIdentityPermission` skip their Exchange Online work when the
  session is not connected to it, `Test-M365DscConnection` gained the same
  switch, and `.build/Export/ExportTenantData.ps1` skips the `EXO*` components
  for such an environment.
- Resolve the Exchange layers of the Datum hierarchy through the same
  `HasExchangeOnline` setting. `source/Datum.yml` replaces both Exchange layers
  with the empty `source/1-AllTenantsConfig/ExchangeDisabled` layer for an
  environment configured without Exchange Online, so no `cEXO*` configuration is
  composed or compiled for it. A new configuration data test guards the
  mechanism.
- Support tenants without a SharePoint Online license. The new per-environment
  setting `HasSharePointOnline` in `source/Global/Azure.yml` is maintained by
  the user. `source/Datum.yml` replaces both SharePoint layers with the empty
  `source/1-AllTenantsConfig/SharePointDisabled` layer for an environment
  configured without SharePoint Online, so no `cSPO*` configuration is composed
  or compiled for it, and `.build/Export/ExportTenantData.ps1` skips the `SPO*`
  components. A new configuration data test guards the mechanism.

### Changed

- Update `Microsoft365DSC` to `1.26.729.2` and regenerate its dependency block.
  The new release drops the granular `Microsoft.Graph.*` and
  `Microsoft.PowerApps.Administration.PowerShell` pins in favour of
  `Microsoft.Graph.Authentication` alone, and adds `Az.Subscription`,
  `Az.Security` and `PSParallelPipeline`.
- Update `ComputerManagementDsc` to `10.0.0`, `NetworkingDsc` to `9.1.0`,
  `PSDesiredStateConfiguration` to `2.0.8` and `Az.KeyVault` to `6.4.2`.
- Update `DscConfig.M365` to `0.7.0-preview0001`.
- Bootstrap `Microsoft.PowerShell.PSResourceGet` `1.2.0` instead of `1.0.1`.
- Pin `AutomatedLab` to `5.61.0` in `lab/00 Prep.ps1` instead of
  `5.57.3-preview`, and add comment-based help to the script.

### Fixed

- Fix the `Build DSC Artifacts` and `Pack DSC Artifacts` steps failing with
  `##[error]Detected characters in arguments that may not be executed correctly
  by the shell. Please escape special characters using backtick`. The
  organization or project has `Enable shell tasks arguments validation` turned
  on, and both steps passed the environment filter as a script block in the
  `arguments` input of `PowerShell@2`, which the validation rejects for its
  `{`, `}` and `$` characters. Escaping them is not an option, because the
  backticks would reach `build.ps1` and turn the script block into a literal
  string. Both steps now call `./build.ps1` from an inline `script`, so no
  `arguments` input is involved and `-Filter` still binds as a `ScriptBlock`.
- Fix the export pipeline failing in `Publish Exported Data` with
  `##[error]Path does not exist: ...\output\Export`. That was the symptom, not
  the cause: `source/Global/Azure.yml` still carried the sample identity
  `<Name of your Application of Managed Identity>` with
  `IsExportApplication: true` next to `M365DscExportApplication`, so
  `.build/Export/ExportTenantData.ps1` matched two export applications and
  stopped with `Multiple export applications defined for environment 'Dev'`
  before it created the export folder. `continueOnError: true` on the export
  step downgraded that to a warning, and the artifact task was the first step
  to fail. The placeholder identity was removed, `ExportTenantData` now ignores
  an identity whose name is still a `<...>` placeholder, its "no export
  application" guard tests the match count instead of `$null` so an empty
  result is caught, and `Export Tenant Configuration` no longer runs with
  `continueOnError`. Converting the export to YAML keeps it, because the raw
  export is still worth publishing when only the conversion fails. A new
  configuration data test asserts that every environment defines exactly one
  export application.
- Fix `lab/31 Agent Setup.ps1` failing to download the Azure Pipelines agent
  with `Exception calling "GetResponse" with "0" argument(s): "No such host is
  known. (vstsagentpackage.azureedge.net:443)"`. That CDN host was retired with
  the Azure CDN from Edgio and no longer resolves. The script now installs all
  build agent software with Chocolatey: `vscode`, `vscode-powershell`, `git`
  and `notepadplusplus` replace the direct downloads and the
  `Install-LabSoftwarePackage` calls, and the `azure-pipelines-agent` package
  supplies the agent binaries from `download.agent.dev.azure.com`. The package
  is installed once without `/Url`, so it only extracts the binaries and the
  personal access token stays out of the Chocolatey command line and log; each
  agent directory is then created from that copy and registered as before.
- Fix `lab/31 Agent Setup.ps1` reporting `The term
  'C:\AL\AzureLabSources.ps1' is not recognized as the name of a cmdlet,
  function, script file, or operable program` three times per run. AutomatedLab
  writes that helper below `$AL_DeployDebugFolder\AL`, which expands to
  `%APPDATA%\DeployDebug\AL` and no longer to the legacy `C:\AL`. With the
  Chocolatey installation the script no longer needs the Azure lab sources
  share on the build agents at all, so the activity that mapped it was removed.

- Fix `lab/30 Create Agent VMs.ps1` registering a superfluous Entra application
  next to the user-assigned managed identity of the build agent, which surfaced
  as `Update-MgApplication_UpdateExpanded: Resource '...' does not exist`
  because Entra had not yet replicated the application it had just created. The
  script now calls `New-M365DscIdentity -OnlyServicePrincipals`, like
  `lab/10 Setup App Registrations.ps1` does for an identity marked
  `IsManagedIdentity`. `Remove-M365DscIdentity` no longer calls
  `Remove-MgApplication` for an identity that has no application registration,
  which is the case for every managed identity.
- Fix the post-deployment validation of `Install-Lab` reporting `Lab deployment
  seems to have failed` for a healthy lab. `AutomatedLabTest` 5.61.4 declares
  its `Dynamics*.tests.ps1` with an empty `-ForEach`, which Pester 6 rejects
  during discovery, and `Invoke-LabPester` passes its own `PesterConfiguration`
  so `$PesterPreference` cannot relax it. `lab/00 Prep.ps1` now installs Pester
  `5.7.1` next to the repository's Pester 6, and `lab/30 Create Agent VMs.ps1`
  imports that version before it calls `Install-Lab`.
- Fix `lab/30 Create Agent VMs.ps1`, `lab/31 Agent Setup.ps1`,
  `lab/88 Start Workers.ps1`, `lab/89 Stop Workers.ps1` and
  `lab/97 Remove Workers and DevOps Project.ps1` stopping with `The tenant
  '...' is not licensed for Exchange Online` on an environment configured with
  `HasExchangeOnline: false`. They called `Connect-M365Dsc` without the
  `SkipExchangeOnline` switch, so the entitlement check ran although none of
  them uses Exchange Online. All five now read `HasExchangeOnline` from the
  environment like `lab/10`, `lab/11` and `lab/98` do, and a new test guards
  every `lab/` script that connects. The error of `Connect-M365Dsc` and the
  hint of `lab/10` no longer point at the removed `ExchangeConfigSet` node
  property; `HasExchangeOnline` is the only setting.
- Fix `lab/20 Configure AzDo Project.ps1` failing to commit the adapted
  pipelines with `fatal: ..\pipelines\build.yml: '..\pipelines\build.yml' is
  outside repository`. `git diff --name-only` reports repository-root relative
  paths, but the script prefixed them with `..`, which only resolved when the
  script was started from the `lab` folder. All git calls of that block now run
  through `git -C <repository root>` and use the reported paths unchanged, so
  the commit and push work from any working directory. `lab/31 Agent Setup.ps1`
  had the same defect in `git add ../source/Global/Azure.yml` and now uses the
  `$PSScriptRoot` based path.
- Fix `Disconnect-M365Dsc` reporting `Disconnect-AzAccount: Method not found:
  'Void Microsoft.Identity.Client.Extensions.Msal.MsalCacheHelper.RegisterCache(Microsoft.Identity.Client.ITokenCache)'`.
  `Az.Accounts` `5.3.2` is built against MSAL `4.65` while
  `Microsoft.Graph.Authentication` `2.35.1` loads MSAL `4.78` into the same
  process, and both versions are dictated by the Microsoft365DSC dependency
  block. The disconnect now falls back to `Clear-AzContext -Scope Process` for
  that specific failure and still surfaces any other error.

- Fix `Connect-M365DscAzure` ignoring the configured subscription for
  application-secret and certificate authentication. Both paths now pass the
  subscription to `Connect-AzAccount` instead of allowing Azure to select the
  account's default subscription.
- Fix `lab/10 Setup App Registrations.ps1` registering the sample placeholder
  identity `<Name of your Application of Managed Identity>` as a real
  application and granting it subscription `Owner`. The loop now skips an
  identity whose name is still a `<...>` placeholder, and routes an identity
  marked `IsManagedIdentity: true` through
  `New-M365DscIdentity -OnlyServicePrincipals` instead of creating an
  application registration for it. Removed the placeholder from
  `source/Global/Azure.yml`, which also unblocks
  `.build/Export/ExportTenantData.ps1`: it rejects a configuration defining more
  than one export application, and the placeholder carried
  `IsExportApplication: true` alongside `M365DscExportApplication`.
- Fix `New-M365DscIdentity -OnlyServicePrincipals -PassThru` failing with
  `Cannot bind argument to parameter 'Name' because it is an empty string`. It
  looked the result up through `$appRegistration.DisplayName`, which is `$null`
  on that code path, and now uses the `Name` parameter.
- Fix `New-AzRoleAssignment` failing with `You are receiving this error because
  you tried to create, update or delete Azure resources without authenticating
  through MFA`. `Add-M365DscIdentityPermission` now replays the claims challenge
  Azure returns through `Connect-AzAccount -ClaimsChallenge` and retries the
  assignment once.
- Fix `Remove-M365DscIdentityPermission` failing to remove the subscription
  `Owner` assignment with the same MFA claims challenge, and reporting
  `Removing the application ... from the role 'Owner'.` although nothing was
  removed. The claims-challenge retry moved into the shared
  `Resolve-M365DscAzureMfaChallenge` function, `Remove-AzRoleAssignment` now
  runs with `-ErrorAction Stop` so a failure is no longer silent, and the
  removal path reports `Done removing Azure permissions` instead of
  `Done adding Azure permissions`.
- Fix `lab/10 Setup App Registrations.ps1` failing with `The term
  'New-M365DSCSelfSignedCertificate' is not recognized` in a session that had
  not run `.\build.ps1 -Tasks init`. `lab/AzHelpers.psm1` calls that function
  but relied on the `InitLab` task having imported `lab/CertHelpers.psm1` into
  the session; it now imports it itself. Without the certificate,
  `New-M365DscIdentity -GenereateCertificate` called `.Export('Cert')` on
  `$null` and sent an empty key credential, so `Update-MgApplication` answered
  `KeyCredentialsInvalidValue`.
- Fix `lab/10 Setup App Registrations.ps1` failing with `The term
  'Get-MgApplication' is not recognized`. The `lab/` scripts call the
  `Microsoft.Graph.*` cmdlets but never declared the modules; they relied on
  Microsoft365DSC pulling them in, and `1.26.729.2` pins only
  `Microsoft.Graph.Authentication`. `RequiredModules.psd1` now pins
  `Microsoft.Graph.Applications`, `Microsoft.Graph.Identity.DirectoryManagement`,
  `Microsoft.Graph.Identity.Governance` and `Microsoft.Graph.Users` at `2.35.1`,
  matching the `Microsoft.Graph.Authentication` version in the generated block.
- Fix `lab/10 Setup App Registrations.ps1` failing with `The term
  'Connect-M365Dsc' is not recognized`. It was the only `lab/` script that never
  imported `AzHelpers.psm1`, so it worked solely by inheriting the module from a
  session that had already run one of the other scripts. Added the same
  `Import-Module -Name $PSScriptRoot\AzHelpers.psm1 -Force` the other scripts
  use.
- Fix `lab/10 Setup App Registrations.ps1` failing to connect with `The term
  'Sync-M365DSCParameter' is not recognized`. Microsoft365DSC no longer ships
  that helper, so `Connect-M365Dsc` in `lab/AzHelpers.psm1` splatted `$null`
  into `Connect-M365DscAzure` and `Connect-M365DscExchangeOnline`. Replaced it
  with the local `Select-M365DscCommandParameter`, which also drops common
  parameters so the explicit `-ErrorAction Stop` at each call site cannot
  collide with a bound `-ErrorAction`.
- Fix `lab/00 Prep.ps1` failing with `The term 'Install-LabAzureRequiredModule'
  is not recognized` in a session that has already run `build.ps1`. `build.yaml`
  configures the Sampler task `Set_PSModulePath` with `RemovePersonal` and
  `RemoveProgramFiles`, so such a session sees neither the modules of the
  current user nor those of all users. The script now restores the default
  module paths for its own process before it does anything else.
- Fix `lab/00 Prep.ps1` never completing the Azure module check. An outdated
  `Az.Accounts` in the `CurrentUser` scope shadows a newer one in `AllUsers`,
  because PowerShell imports from the first `PSModulePath` entry holding the
  module, not from the one with the highest version. The script now removes
  such shadowing copies and, if the check still fails, reports whether the
  session has already loaded an older `Az.Accounts`.
- Fix `lab/00 Prep.ps1` reinstalling `AutomatedLab` on every run. The installed
  version was compared against the full pin including the prerelease tag, which
  a `ModuleInfo.Version` never carries. The failing reinstall then surfaced as a
  misleading `Administrator rights are required` error, which PowerShellGet also
  raises when another session holds the module files open.
- Add an elevation check to `lab/00 Prep.ps1` so a non-elevated session fails
  immediately with an actionable message instead of part way through.
- Fix the `TestConfigData` build task failing with Pester 6, which rejects an
  empty `-TestCases` collection during discovery. The node definition files are
  now looked up through `AllNodes` instead of the non-existing `BuildAgents`
  key, and the roles tests are only created when role definition files exist.
- Fix dependency resolution failing with `Requested value 'V2' was not found`.
  `Microsoft.PowerShell.PSResourceGet` `1.0.1` cannot read a
  `PSResourceRepository.xml` written by version `1.1` or later.
- Fix the build failing in `TestConfigData` with `Cannot find path
  'output\RequiredModules\DscConfig.M365'`. `RequiredModules.psd1` pinned
  `DscConfig.M365` `0.7.9-preview0001`, which is not published on the
  PowerShell Gallery, so the restore skipped the module and
  `CompositeResources.Tests.ps1` failed during discovery.
