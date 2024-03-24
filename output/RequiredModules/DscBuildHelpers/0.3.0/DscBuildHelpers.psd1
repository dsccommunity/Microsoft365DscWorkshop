@{
    RootModule        = 'DscBuildHelpers.psm1'

    ModuleVersion     = '0.3.0'

    GUID              = '23ccd4bf-0a52-4077-986f-c153893e5a6a'

    Author            = 'Gael Colas'

    Copyright         = '(c) 2022 Gael Colas. All rights reserved.'

    Description       = 'Build Helpers for DSC Resources and Configurations'

    PowerShellVersion = '5.0'

    RequiredModules = @(
        @{ ModuleName = 'xDscResourceDesigner'; ModuleVersion = '1.9.0.0'} #tested with 1.9.0.0
    )

    FunctionsToExport = @('Clear-CachedDscResource','Compress-DscResourceModule','Find-ModuleToPublish','Get-DscCimInstanceReference','Get-DscFailedResource','Get-DscResourceFromModuleInFolder','Get-DscResourceProperty','Get-DscResourceWmiClass','Get-DscSplattedResource','Get-ModuleFromFolder','Initialize-DscResourceMetaInfo','Publish-DscConfiguration','Publish-DscResourceModule','Push-DscConfiguration','Push-DscModuleToNode','Remove-DscResourceWmiClass','Test-DscResourceFromModuleInFolderIsValid')

    PrivateData = @{

        PSData = @{

            Prerelease = 'fix0001'

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags         = @('DesiredStateConfiguration', 'DSC', 'BuildHelpers', 'DSCResource')

            # A URL to the license for this module.
            #LicenseUri = 'https://github.com/gaelcolas/DscBuildHelpers/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/gaelcolas/DscBuildHelpers'

            # A URL to an icon representing this module.
            IconUri      = 'https://dsccommunity.org/images/DSC_Logo_300p.png'

            # ReleaseNotes of this module
            ReleaseNotes = '## [0.2.0-fix0001] - 2024-03-24

### Added

- Added support for CIM based properties.

### Changed

- Migration of build pipeline to Sampler.

### Fixed

- Initialize-DscResourceMetaInfo:
  - Fixed TypeConstraint, ''MSFT_KeyValuePair'' should be ignored.
  - Fixed non-working caching test.
  - Added PassThru pattern for easier debugging.
  - Considering CIM instances names DSC_* in addition to MSFT_*.
- Get-DscResourceFromModuleInFolder:
  - Redesigned the function. It did not work with PowerShell 7 and
    PSDesiredStateConfiguration 2.0.7.
- Changed the remaining lines in alignment to PR #14.
'

        } # End of PSData hashtable

    } # End of PrivateData hashtable
}
