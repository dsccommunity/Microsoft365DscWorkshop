& "$PSScriptRoot\..\..\build.ps1" -Tasks Init
& "$PSScriptRoot\..\..\lab\11 Test Connection.ps1" -EnvironmentName Dev -DoNotDisconnect
Import-Module -Name NameIT -ErrorAction SilentlyContinue

$appCount = 5
$azureDevOpsProjectUrl = "https://dev.azure.com/$($datum.Global.ProjectSettings.OrganizationName)/$($datum.Global.ProjectSettings.ProjectName)"
$tenantId = $datum.Global.Azure.Environments.Dev.AzTenantId
$tenantName = $datum.Global.Azure.Environments.Dev.AzTenantName
$azureDevOpsPat = $datum.Global.ProjectSettings.PersonalAccessToken
[System.Collections.ArrayList]$passwords = Invoke-Generate -Template '[person female last][numeric][numeric][numeric][numeric]' -Count 500 | Where-Object { $_.Length -ge 8 -and $_.Length -le 20 }
$outputPath = "$PSScriptRoot\AppInfo"

if (-not (Test-Path -Path $outputPath))
{
    New-Item -Path $outputPath -ItemType Directory -Force | Out-Null
}
else
{
    Remove-Item -Path $outputPath -Recurse -Force
    New-Item -Path $outputPath -ItemType Directory -Force | Out-Null
}

for ($i = 1; $i -le $appCount; $i++)
{
    $app = Get-M365DscIdentity -Name "TestApp$i"
    if ($app)
    {
        Write-Host "App already exists: $($app.DisplayName) with ID: $($app.AppId), removing it."
        Remove-M365DscIdentity -Identity $app
    }
}

$result = for ($i = 1; $i -le $appCount; $i++)
{
    $app = New-M365DscIdentity -Name "TestApp$i" -GenereateAppSecret -PassThru
    Write-Host "Created app: $($app.DisplayName) with ID: $($app.AppId)"
    Add-M365DscIdentityPermission -Identity $app -Permissions 'Group.ReadWrite.All'
    Write-Host "Added permission to app: $($app.DisplayName)"
    $app | Add-Member -Name Index -Value $i -MemberType NoteProperty -PassThru
}

foreach ($app in $result)
{
    Write-Host "Adding encrypted secret to app: $($app.DisplayName)" -NoNewline
    $key = Invoke-Generate
    $app | Add-Member -Name Key -Value $key -MemberType NoteProperty -Force
    $app | Add-Member -Name EncSecret -Value ($app.Secret | Protect-Datum -Password ($key | ConvertTo-SecureString -AsPlainText -Force)) -MemberType NoteProperty -Force
    Write-Host ' - Done'
}

$result = foreach ($app in $result)
{
    $index = Get-Random -Minimum 0 -Maximum $passwords.Count
    $password = $passwords[$index]
    $passwords.RemoveAt($index)

    $existingTestUser = Get-M365DscTestUser -Name "SummitTestUser$($app.Index)"
    if ($existingTestUser)
    {
        Write-Host "Test user already exists: $($existingTestUser.DisplayName), removing it."
        Remove-M365DscTestUser -User $existingTestUser | Out-Null
    }

    $user = New-M365DscTestUser -Name "SummitTestUser$($app.Index)" -Password ($password | ConvertTo-SecureString -AsPlainText -Force) -DisablePasswordExpiration
    Write-Host "Created test user: $($user.DisplayName) with ID: $($user.Id)."

    $user | Add-M365DscTestUserToAzDevOps -ProjectUrl $azureDevOpsProjectUrl -AccessLevel express -PersonalAccessToken $azureDevOpsPat -AddAsTeamContributor | Out-Null
    Write-Host "Added test user to Azure DevOps project $($datum.Global.ProjectSettings.ProjectName)."

    try
    {
        $user | Add-M365DscRepositoryPermission -ProjectUrl $azureDevOpsProjectUrl -PersonalAccessToken $azureDevOpsPat -RepositoryName $datum.Global.ProjectSettings.ProjectName -Permissions CreateBranchPermission, ReadPermission -ErrorAction Stop | Out-Null
    }
    catch
    {
        #Let's try again
        $user | Add-M365DscRepositoryPermission -ProjectUrl $azureDevOpsProjectUrl -PersonalAccessToken $azureDevOpsPat -RepositoryName $datum.Global.ProjectSettings.ProjectName -Permissions CreateBranchPermission, ReadPermission -ErrorAction Stop | Out-Null
    }

    $userPassword = $password | Protect-Datum -Password ($app.Key | ConvertTo-SecureString -AsPlainText -Force)

    $app | Add-Member -Name UserName -Value $user.DisplayName -MemberType NoteProperty -Force
    $app | Add-Member -Name UserPassword -Value $userPassword -MemberType NoteProperty -Force
    $app | Add-Member -Name UserPasswordPlain -Value $password -MemberType NoteProperty -Force
    $app | Add-Member -Name UserUpn -Value $user.UserPrincipalName -MemberType NoteProperty -Force
    $app
}

foreach ($app in $result)
{
    $fileContent = [ordered]@{
        AppId          = $app.AppId
        AppDisplayName = $app.DisplayName
        EncSecret      = $app.EncSecret
        TenantId       = $tenantId
        TenantName     = $tenantName
        UserName       = "$($app.UserName)@$tenantName"
        UserPassword   = $app.UserPassword
    }

    $fileContentYaml = $fileContent | ConvertTo-Yaml

    $fileContentYaml | Set-Content -Path "$outputPath/$($app.UserName).yaml" -Force
    Write-Host "Saved app info to file: $outputPath/$($app.UserName).yaml"
}

$result | Select-Object -ExcludeProperty EncSecret, UserPassword | Export-Csv -Path "$PSScriptRoot/Apps.csv"
Write-Host "Exported app info to CSV '$PSScriptRoot/Apps.csv'."
