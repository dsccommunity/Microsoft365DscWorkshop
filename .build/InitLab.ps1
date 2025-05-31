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

    $modulesToImport = @(
        'ExchangeOnlineManagement',
        'Az.Accounts',
        'Az.Resources',
        'Microsoft365DSC'
    )

    foreach ($moduleToImport in $modulesToImport)
    {
        $module = Get-Module -Name $moduleToImport -ListAvailable |
            Sort-Object -Property Version -Descending |
                Select-Object -First 1 |
                    Import-Module -PassThru
        Write-Host "'$module' module version $($module.Version) is imported to make sure the highest available version is used." -ForegroundColor Yellow

    }

}
