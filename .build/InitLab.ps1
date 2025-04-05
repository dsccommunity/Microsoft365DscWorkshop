task InitLab {

    Write-Host "Importing module 'AzHelpers' from path '$ProjectPath\lab\AzHelpers.psm1'." -ForegroundColor Yellow
    Import-Module -Name $ProjectPath\lab\AzHelpers.psm1 -Force

    Write-Host "Importing module 'CertHelpers' from path '$ProjectPath\lab\CertHelpers.psm1'." -ForegroundColor Yellow
    Import-Module -Name $ProjectPath\lab\CertHelpers.psm1 -Force

    Write-Host "Importing module 'M365DscHelpers' from path '$ProjectPath\lab\M365DscHelpers.psm1'." -ForegroundColor Yellow
    Import-Module -Name $ProjectPath\lab\M365DscHelpers.psm1 -Force

    if ($PSVersionTable.PSEdition -eq 'Core')
    {
        Write-Host "Importing module 'MofConvert' from path '$ProjectPath\export\MofConvert.psm1'." -ForegroundColor Yellow
        Import-Module -Name $ProjectPath\export\MofConvert.psm1 -Force
    }
    else
    {
        Write-Host "The module 'MofConvert.psm1' cannot be loaded on Windows PowerShell."
    }

    if (Get-Module -Name AutomatedLab -ListAvailable)
    {
        Write-Host "Importing module 'AutomatedLab'..." -NoNewline -ForegroundColor Yellow

        try
        {
            #Import-Module -Name AutomatedLab -Force -ErrorAction Stop
        }
        catch
        {
            Write-Host 'failed, retrying...' -NoNewline -ForegroundColor Yellow
            #Import-Module -Name AutomatedLab -Force -ErrorAction Stop
            Write-Host 'succeeded.' -ForegroundColor Yellow
        }
    }
    else
    {
        Write-Host "Module 'AutomatedLab' is not installed, module will not be imported." -ForegroundColor Yellow
    }

    Write-Host ''

    $azAccountsModule = Get-Module -Name Az.Accounts -ListAvailable |
        Sort-Object -Property Version -Descending |
            Select-Object -First 1 |
                Import-Module -PassThru
    Write-Host "'Az.Accounts' module version $($azAccountsModule.Version) is imported to make sure the highest available version is used." -ForegroundColor Yellow

    $azResourceModule = Get-Module -Name Az.Resources -ListAvailable |
        Sort-Object -Property Version -Descending |
            Select-Object -First 1 |
                Import-Module -PassThru
    Write-Host "'Az.Resources' module version $($azResourceModule.Version) is imported to make sure the highest available version is used." -ForegroundColor Yellow

    Write-Host "Importing module 'Microsoft365DSC' from path '$RequiredModulesDirectory'." -ForegroundColor Yellow
    Import-Module -Name Microsoft365DSC -Force

}
