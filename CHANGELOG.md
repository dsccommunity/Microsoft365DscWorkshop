# Changelog for DscPipeline

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial Upload

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
