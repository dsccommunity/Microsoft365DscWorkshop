task ShellInit {

    Write-Host 'Importing module 'AzHelpers' from path '$ProjectPath\lab\AzHelpers.psm1'.' -ForegroundColor Yellow
    Import-Module -Name $ProjectPath\lab\AzHelpers.psm1 -Force

    Write-Host 'Importing module 'AutomatedLab'.' -ForegroundColor Yellow
    Import-Module -Name AutomatedLab -Force

}
