@{
    Gallery         = 'PSGallery'
    AllowPrerelease = $false
    WithYAML        = $true

    UsePSResourceGet = $true
    # 1.0.1 cannot read a PSResourceRepository.xml written by 1.1+ ("Requested value 'V2' was not found").
    PSResourceGetVersion = '1.2.0'

    # PowerShellGet compatibility module only works when using PSResourceGet or ModuleFast.
    UsePowerShellGetCompatibilityModule = $true
    UsePowerShellGetCompatibilityModuleVersion = '3.0.23-beta23'
}
