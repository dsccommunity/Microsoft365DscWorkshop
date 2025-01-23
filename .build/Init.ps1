task Init {

    Write-Host 'Importing module 'AzHelpers' from path '$ProjectPath\lab\AzHelpers.psm1'.' -ForegroundColor Yellow
    Import-Module -Name $ProjectPath\lab\AzHelpers.psm1 -Force

    Write-Host 'Importing module 'CertHelpers' from path '$ProjectPath\lab\CertHelpers.psm1'.' -ForegroundColor Yellow
    Import-Module -Name $ProjectPath\lab\CertHelpers.psm1 -Force

    Write-Host 'Importing module 'MofConvert' from path '$ProjectPath\export\MofConvert.psm1'.' -ForegroundColor Yellow
    Import-Module -Name $ProjectPath\export\MofConvert.psm1 -Force

    if (Get-Module -Name AutomatedLab -ListAvailable)
    {
        Write-Host 'Importing module 'AutomatedLab'.' -ForegroundColor Yellow
        Import-Module -Name AutomatedLab -Force
    }
    else
    {
        Write-Host 'Module 'AutomatedLab' is not installed, module will not be imported.' -ForegroundColor Yellow
    }

}
