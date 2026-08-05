---
status: current
last-verified: 2026-08-05
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

`lab/11 Test Connection.ps1` connected to the Azure account's default
subscription instead of the subscription configured for the Dev environment.
The repository fix and regression test are complete and remain uncommitted, as
requested.

## Evidence

- `source/Global/Azure.yml` configures Dev subscription
  `9522bd96-d34f-4910-9667-0517ab5dc595`, but application-secret authentication
  connected to the account's other subscription
  `<other-subscription-id>`. Validation correctly exposed the mismatch.
- `Connect-M365DscAzure` forwarded `SubscriptionId` only in its interactive
  branch. Its application-secret and certificate branches omitted the value
  from `Connect-AzAccount`, which then selected the account's default Azure
  context. Both branches now pass the canonical `Subscription` parameter when
  a subscription is configured.
- Az.Accounts `5.3.2` exposes `Subscription` in both
  `ServicePrincipalWithSubscriptionId` and
  `ServicePrincipalCertificateWithSubscriptionId`; `SubscriptionId` is an
  alias. A focused Pester 6.0.1 regression test covers both branches: 2 passed,
  0 failed.
- Final `\.\build.ps1 -Tasks rsop`: 131 tests passed, 0 failed; 7 tasks,
  0 errors and 0 warnings.
- The exact live command `& '.\lab\11 Test Connection.ps1'` now connects to
  `<dev-subscription-name>` (`9522bd96-d34f-4910-9667-0517ab5dc595`). Azure
  tenant and subscription, Microsoft Graph tenant, and Exchange Online tenant
  validation all pass before the script disconnects cleanly.
- The placeholder identity `<Name of your Application of Managed Identity>` was
  registered as application `<registered-application-id>` on
  2026-08-05. It received 166 Graph application permissions and the `Global
  Reader` and `Exchange Administrator` directory roles. The subscription `Owner`
  assignment failed on the MFA claims challenge, and the eight Exchange role
  groups failed on licensing, so those two did not take effect. Cleanup is
  `Remove-M365DscIdentityPermission` followed by `Remove-M365DscIdentity`; not
  run, it needs the user's approval.
- `New-M365DscIdentity -OnlyServicePrincipals -PassThru` was broken: it looked
  the result up through `$appRegistration.DisplayName`, which is `$null` on that
  path. Changed to the `Name` parameter, which is what the application is
  created and searched with anyway.
- The claims-challenge regex was tested against the verbatim `New-AzRoleAssignment`
  error text: it captures `eyJhY2Nlc3NfdG9rZW4i...`, which decodes to
  `{"access_token":{"acrs":{"essential":true,"values":["p1"]}}}`; an unrelated
  error text does not match, so it rethrows.
- The placeholder guard `^<.+>$` matches only the placeholder, not
  `M365DscSetupApplication`, `M365DscLcmApplication` or
  `M365DscExportApplication`.
- After removing the placeholder from `source/Global/Azure.yml`,
  `New-DatumStructure` resolves three identities and exactly one export
  application, which is what `.build/Export/ExportTenantData.ps1` requires.
- `.\build.ps1 -Tasks rsop`: `Build succeeded. 7 tasks, 0 errors, 0 warnings` in
  27 seconds, 129 configuration-data tests, 0 failures.
- `.\build.ps1 -Tasks init` is a documented prerequisite
  (`docs/GettingStarted.md` 1.4.1) and `.build/InitLab.ps1` imports `AzHelpers`,
  `CertHelpers` and `M365DscHelpers` into the session. Skipping it produced
  `The term 'New-M365DSCSelfSignedCertificate' is not recognized`, because
  `New-M365DscIdentity -GenereateCertificate` resolved that function only
  through the global session state. `AzHelpers.psm1` now imports `CertHelpers`
  itself; verified in a clean `pwsh -NoProfile` that importing `AzHelpers` alone
  exports 20 functions including `New-M365DSCSelfSignedCertificate`.
  `Invoke-ScriptAnalyzer` reports the same 71 pre-existing findings, AST parse 0
  errors.
- `init` does not explain the other three failures of the same run: the missing
  `Microsoft.Graph.*` modules were absent from disk and `InitLab` imports only
  `ExchangeOnlineManagement`, `Az.Accounts`, `Az.Resources` and
  `Microsoft365DSC`; the `New-AzRoleAssignment` MFA claims challenge is a tenant
  Conditional Access requirement; and `Add-RoleGroupMember` failing with
  `Organization ... is not licensed for Exchange email functionality` is tenant
  licensing.
- The script failed with `The term 'Get-MgApplication' is not recognized`, then
  cascaded into `Get-M365DscIdentity: Cannot bind argument to parameter 'Name'`
  and `The property 'Secret' cannot be found on this object`, because
  `New-M365DscIdentity` kept going with a `$null` application. Only
  `Microsoft.Graph.Authentication` `2.35.1` was installed on the machine.
- `git show 467c719^:RequiredModules.psd1` lists 26 `Microsoft.Graph.*` pins at
  `2.28.0` under Microsoft365DSC `1.25.730.1`. `1.26.729.2` pins
  `Microsoft.Graph.Authentication` alone, so the lab scripts lost the SDK they
  had been free-riding on. `RequiredModules.psd1` now declares the four
  sub-modules they need, outside the generated block.
- All four exist on the gallery at `2.35.1` (latest is `2.39.0`). Verified in a
  clean `pwsh -NoProfile` after saving them: all 25 `Mg*` cmdlets used by
  `lab/AzHelpers.psm1` and `lab/M365DscHelpers.psm1` resolve at `2.35.1`, and
  `AzHelpers` still imports.
- `.\build.ps1 -ResolveDependency -Tasks noop` aborted on
  `Access to the path 'PowerShellYamlSerializer.dll' is denied`. Four other
  `pwsh` processes held `powershell-yaml`. `Resolve-Dependency.ps1` skips that
  module only when the *restoring* session has it loaded, so a lock held by
  another process still fails the save. The four modules were saved with the
  same `Save-PSResource` call `Resolve-Dependency` makes.
- `AADSTS500014` on Exchange Online, seen earlier in the session, was a lapsed
  Microsoft 365 subscription in the Dev tenant: zero subscribed SKUs, all 88
  `organization.assignedPlans` entries `Deleted`, and the Exchange, SharePoint,
  Teams and Management API service principals disabled while Graph stayed
  enabled. Resolved outside this repository.

- `lab/10 Setup App Registrations.ps1` was the only `lab/` script without
  `Import-Module -Name $PSScriptRoot\AzHelpers.psm1 -Force`; `11`, `30`, `31`,
  `88`, `89` and `97` all carry it, and `.build/InitLab.ps1` imports the module
  too. It only ever ran because a session that had executed another script still
  held the module. A `CommandNotFoundException` also aborts the whole `if`
  statement, so the failed `Test-M365DscConnection` guard was skipped instead of
  stopping the script, and the run continued into `New-M365DscIdentity`.
- Verified in a clean `pwsh -NoProfile`: after the added import, all of
  `Connect-M365Dsc`, `Disconnect-M365Dsc`, `Test-M365DscConnection`,
  `New-M365DscIdentity`, `Add-M365DscIdentityPermission` and
  `Select-M365DscCommandParameter` resolve from `AzHelpers`, and
  `New-DatumStructure`, `Protect-Datum` and `ConvertTo-Yaml` resolve from
  `output/RequiredModules`. `New-DatumStructure` loads and yields the `Dev`
  environment.
- `source/Global/Azure.yml` still lists a fourth identity named
  `<Name of your Application of Managed Identity>` with `IsManagedIdentity: true`.
  Nothing under `lab/` reads `IsManagedIdentity`, so the loop would register an
  application under that literal name and assign it subscription `Owner`. Not
  changed; it is tenant data the user owns.
- `Sync-M365DSCParameter` has 0 occurrences in the pinned Microsoft365DSC
  `1.26.729.2` package; older releases exported it from `M365DSCUtil.psm1`.
  `Connect-M365Dsc` called it twice, so `$param` was `$null` and
  `Connect-M365DscAzure @param` passed `$null` positionally, which produced the
  misleading `A positional parameter cannot be found that accepts argument
  '$null'` and left every service unconnected.
- `Select-M365DscCommandParameter` now does the filtering locally. Verified in
  an imported session: for `@{TenantId;TenantName;SubscriptionId;ErrorAction}`
  it returns `TenantId,TenantName` for `Connect-M365DscExchangeOnline` and
  `TenantId,SubscriptionId` for `Connect-M365DscAzure`. AST parse reports 0
  errors and `Invoke-ScriptAnalyzer` reports no new findings.
- `Get-AzAccessToken` in `Az.Accounts` `5.3.2` returns `Token` as a
  `SecureString`, and `Connect-MgGraph -AccessToken` in
  `Microsoft.Graph.Authentication` `2.35.1` takes `SecureString`. The token hand-off
  inside `Connect-M365DscAzure` therefore needs no change.

## Earlier evidence

- `build.yaml` configures the Sampler task `Set_PSModulePath` with
  `RemovePersonal: true` and `RemoveProgramFiles: true`. A session that ran
  `build.ps1` therefore sees neither the CurrentUser nor the AllUsers module
  scope. Running `lab/00 Prep.ps1` there reinstalled `AutomatedLab` although
  5.61.0 was present, `Install-Module` resolved to the PSResourceGet
  compatibility shim and prompted about the untrusted gallery, and
  `Install-LabAzureRequiredModule` and `Get-LabConfigurationItem` were still
  unrecognized. `Restore-DefaultModulePath` now repairs the process
  `PSModulePath` first. Measured in a session with the stripped path:
  `AutomatedLab` went from 0 to 2 discovered copies and both commands resolved,
  while `output/RequiredModules` was kept behind the defaults.
- `Az.Accounts` `5.5.1` sat in `C:\Users\<user>\Documents\PowerShell\Modules`
  while `5.5.2` sat in `C:\Program Files\PowerShell\Modules`. PowerShell imports
  from the first `PSModulePath` entry containing a module, and the CurrentUser
  path comes first, so every session loaded `5.5.1`. `Az.Storage` `9.7.2`
  demands `5.5.2`, hence `Test-LabAzureModuleAvailability` returned `$false` in
  a completely clean `pwsh -NoProfile` too. Restarting the script could never
  help.
- `AutomatedLab` `5.57.3-preview` in `C:\Program Files\PowerShell\Modules`
  shadowed `5.61.0` in `C:\Program Files\WindowsPowerShell\Modules`, while every
  AutomatedLab sub-module on the machine was already `5.61.0`.
- The pin `5.57.3-preview` was never recognised as installed:
  `Where-Object Version -eq '5.57.3-preview'` compares a `[version]` against the
  full prerelease string. The script reinstalled `AutomatedLab` on every run.
- The `Administrator rights are required` message was a false lead. Reproduced
  in an elevated session: PowerShellGet's `Copy-Module` raises
  `AdministratorRightsNeededOrSpecifyCurrentUserScope` when the destination
  module is in use by another PowerShell process.
- `Get-LabConfigurationItem -Name RequiredAzModules` lists Az.Accounts,
  Az.Storage, Az.Compute, Az.Network, Az.Resources, Az.Websites and Az.Security.
  `Install-LabAzureRequiredModule` accepts any installed copy at or above the
  minimum version, so it never repairs a shadowed scope.
- After the fix, a clean `pwsh -NoProfile` run of the script removed
  `Az.Accounts 5.5.1` and `AutomatedLab 5.57.3`, and
  `Test-LabAzureModuleAvailability` loaded all seven Az modules without a
  version conflict. The run then stopped at the interactive
  `Enable-LabHostRemoting` confirmation, which needs a real user at the console.
- `Invoke-ScriptAnalyzer` reports no findings besides the pre-existing
  `PSAvoidUsingWriteHost` warnings, and `Get-Help` resolves the new script-level
  help rather than the help of `Resolve-ShadowedModule`.

- `RequiredModules.psd1` pinned `DscConfig.M365` `0.7.9-preview0001`, a version
  that is not published on the PowerShell Gallery. The newest published releases
  are `0.6.1` (stable) and `0.7.0-preview0001`, both from 2026-08-04.
- The restore skipped the module without failing, leaving 51 folders in
  `output/RequiredModules` and no `DscConfig.M365`. `TestConfigData` then failed
  during Pester discovery with `Cannot find path ...\DscConfig.M365`, because
  `tests/ConfigData/CompositeResources.Tests.ps1` resolves every entry of
  `build.yaml`'s `Sampler.DscPipeline.DscCompositeResourceModules`. Only 73 of
  129 configuration-data tests ran.
- `.\build.ps1` after that fix: `Build succeeded. 21 tasks, 0 errors, 0 warnings`
  in 5 minutes 31 seconds, with 129 configuration-data tests and 12 acceptance
  tests, both 0 failures.
- `RequiredModules.psd1` pins Microsoft365DSC `1.26.729.2`,
  ComputerManagementDsc `10.0.0`, NetworkingDsc `9.1.0`,
  PSDesiredStateConfiguration `2.0.8` and Az.KeyVault `6.4.2`.
- `Resolve-Dependency.psd1` bootstraps `Microsoft.PowerShell.PSResourceGet`
  `1.2.0`. Version `1.0.1` aborted the restore with `Requested value 'V2' was
  not found`.

## Open risk

`.memory-bank/` is tracked, so a push sends it to the public repository. The
three identifiers that `HEAD` did not already contain — the account's second
subscription ID, the application ID registered on 2026-08-05, and the Dev
subscription display name — are redacted to angle-bracket placeholders in this
file and in `progress.md`. Keep new tenant facts redacted the same way.

The new `tests/ConfigData/AzHelpers.Tests.ps1` still hard-codes the live tenant
and subscription IDs as mock values. Both are already public through
`docs/GettingStarted.md` and `export/readme.md`, so this exposes nothing new,
but the mocks would work just as well with placeholder GUIDs.

## Next step

No further repository action is required for the subscription-selection defect.
