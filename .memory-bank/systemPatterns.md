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

### Decision 8: Resolve module shadowing by path order, not by version alone

- Choice: `lab/00 Prep.ps1` carries `Resolve-ShadowedModule`, which deletes
  every copy of a required module that is older than the newest installed copy
  and sits in a `PSModulePath` entry preceding the one holding the newest copy.
  It only inspects the four standard module scopes.
- Rationale: PowerShell imports the highest version found in the *first*
  `PSModulePath` entry containing the module, so `Az.Accounts` 5.5.1 under
  `Documents\PowerShell\Modules` permanently shadowed 5.5.2 under
  `Program Files\PowerShell\Modules` and made `Test-LabAzureModuleAvailability`
  fail forever. `Install-LabAzureRequiredModule` cannot detect this because its
  presence check accepts any installed copy above the minimum version.
  Restricting the cleanup to the standard scopes keeps a Sampler build's
  `output/RequiredModules`, which is prepended to `PSModulePath`, untouched.

### Decision 9: Compare a prerelease pin in two parts

- Choice: Split a pin such as `5.57.3-preview` on the first `-` and compare the
  base version against `ModuleInfo.Version` and the tag against
  `PrivateData.PSData.Prerelease`.
- Rationale: `ModuleInfo.Version` never carries the prerelease tag, so
  `Where-Object Version -eq '5.57.3-preview'` never matches. `lab/00 Prep.ps1`
  therefore reinstalled `AutomatedLab` on every run, and the reinstall failed
  with PowerShellGet's misleading `AdministratorRightsNeededOrSpecifyCurrentUserScope`
  error, which it also raises when another session holds the module files open.

### Decision 10: Repair `PSModulePath` inside the lab prep script

- Choice: `lab/00 Prep.ps1` calls `Restore-DefaultModulePath` before any other
  step, prepending the default module paths of the running edition and keeping
  build-added paths behind them. The change is process-local.
- Rationale: `build.yaml` configures `Set_PSModulePath` with `RemovePersonal`
  and `RemoveProgramFiles`, so a session that ran `build.ps1` sees neither the
  CurrentUser nor the AllUsers module scope. In such a session the prep script
  reinstalled `AutomatedLab` although it was present, `Install-Module` resolved
  to the PSResourceGet compatibility shim and prompted about the untrusted
  gallery, and `Install-LabAzureRequiredModule` and `Get-LabConfigurationItem`
  were still unrecognized afterwards. Users do rerun the script in an existing
  shell, so refusing to run there would be worse than repairing the path.

### Decision 11: Keep the lab helpers free of Microsoft365DSC internals

- Choice: `lab/AzHelpers.psm1` carries its own
  `Select-M365DscCommandParameter` instead of calling Microsoft365DSC's
  `Sync-M365DSCParameter`.
- Rationale: `Sync-M365DSCParameter` was an undocumented utility that
  Microsoft365DSC dropped by `1.26.729.2`, and its loss broke
  `lab/10 Setup App Registrations.ps1` in a way that pointed at the wrong
  place: the failed call returned `$null`, and splatting `$null` passes it as a
  positional argument, so the visible error was `A positional parameter cannot
  be found that accepts argument '$null'` on `Connect-M365DscAzure`. A pinned
  dependency's internal helpers are not an API; parameter filtering is three
  lines and belongs to the caller.

### Decision 12: Check tenant entitlement before debugging a lab connection

- Choice: When a `lab/` connection fails with an `AADSTS5000xx` code, first read
  `subscribedSkus`, `organization.assignedPlans` and the `accountEnabled` flag
  of the workload service principal, using a Graph token minted from the cached
  Az context rather than a fresh interactive sign-in.
- Rationale: `AADSTS500014` on `https://outlook.office365.com` means Entra ID
  refuses to mint a token because the resource service principal is disabled,
  which happens when the tenant's Microsoft 365 subscription lapses. The Dev
  sandbox tenant reached that state on 2026-08-05: zero subscribed SKUs, all 88
  assigned plans `Deleted`, and Exchange, SharePoint, Teams and the Management
  APIs all disabled while Graph stayed enabled. Three read-only Graph calls
  separate a dead tenant from a code defect and stop the search in the wrong
  repository.

### Decision 13: Declare the Graph SDK sub-modules the lab scripts use

- Choice: `RequiredModules.psd1` pins `Microsoft.Graph.Applications`,
  `Microsoft.Graph.Identity.DirectoryManagement`,
  `Microsoft.Graph.Identity.Governance` and `Microsoft.Graph.Users` in its own
  section, above the generated Microsoft365DSC block, at the version the
  generated block pins for `Microsoft.Graph.Authentication`.
- Rationale: `lab/AzHelpers.psm1` and `lab/M365DscHelpers.psm1` call 25 `Mg*`
  cmdlets but declared none of the modules. Microsoft365DSC `1.25.730.1` pinned
  26 `Microsoft.Graph.*` modules and the lab free-rode on them; `1.26.729.2`
  moved to raw Graph requests and pins only
  `Microsoft.Graph.Authentication`, which silently removed every cmdlet the lab
  needs. A caller's dependencies belong to the caller. The pins stay outside the
  generated block so regenerating it cannot drop them again, and the version has
  to be kept in sync by hand because each sub-module manifest requires that
  exact `Microsoft.Graph.Authentication` version.

### Decision 14: A lab helper module imports its own dependencies

- Choice: `lab/AzHelpers.psm1` imports `lab/CertHelpers.psm1` itself rather than
  relying on the caller. `.build/InitLab.ps1` keeps importing all three lab
  modules into the session, because `export/readme.md` documents interactive use
  of `New-M365DSCSelfSignedCertificate`.
- Rationale: `New-M365DscIdentity -GenereateCertificate` resolved
  `New-M365DSCSelfSignedCertificate` only through the global session state that
  `.\build.ps1 -Tasks init` sets up. A session that skipped the documented
  prerequisite got `The term ... is not recognized`, then `.Export('Cert')` on
  `$null`, then an empty key credential and a `KeyCredentialsInvalidValue` from
  Graph — three misleading errors for one missing import. Dot-sourcing is not an
  alternative: `. <file>.psm1` is a silent no-op, it defines nothing and raises
  no error.

### Decision 15: Skip an unfilled placeholder instead of provisioning it

- Choice: `lab/10 Setup App Registrations.ps1` skips an identity whose `Name`
  still matches `^<.+>$`, and treats `IsManagedIdentity: true` as "the principal
  already exists" by calling `New-M365DscIdentity -OnlyServicePrincipals`.
- Rationale: the sample `source/Global/Azure.yml` shipped
  `<Name of your Application of Managed Identity>`, and the loop read only
  `ApplicationSecret` and `CertificateThumbprint`. It registered a real
  application under that literal name and granted it subscription `Owner`,
  Global Reader and Exchange Administrator. Configuration data that a user is
  expected to fill in must fail closed. The documented single-tenant example in
  `docs/GettingStarted.md` lists only the three real identities, so the
  placeholder was removed from the file as well.

### Decision 16: Replay the Azure claims challenge, do not force MFA at sign-in

- Choice: `Add-M365DscIdentityPermission` catches the `New-AzRoleAssignment`
  failure, extracts the challenge from the error text, calls
  `Connect-AzAccount -ClaimsChallenge` and retries once. Any other error is
  rethrown.
- Rationale: Azure requires an MFA-satisfied token for resource management and
  returns `{"access_token":{"acrs":{"essential":true,"values":["p1"]}}}` to
  replay. Requesting that authentication context up front in
  `Connect-M365DscAzure` would block an account with no registered MFA method
  even for the read-only parts of the workshop, so the challenge is honoured
  only when Azure actually raises it.

### Decision 17: Always bind a configured Azure subscription

- Choice: Every `Connect-AzAccount` path in `Connect-M365DscAzure` passes the
  canonical `Subscription` parameter when `SubscriptionId` was supplied,
  including application-secret and certificate authentication.
- Rationale: In a tenant with multiple subscriptions, service-principal
  authentication otherwise selects the Azure account's default subscription.
  The connection can look successful while targeting the wrong subscription;
  the subsequent context validation then fails. Offline Pester tests guard both
  service-principal paths.
