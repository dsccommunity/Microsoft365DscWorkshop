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

### Fixed

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
