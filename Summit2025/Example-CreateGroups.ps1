#
# Example script to demonstrate using the Create-EntraIDGroup.ps1 script
# This shows how to create different types of Entra ID groups using Microsoft Graph
#

# Set up your application and authentication details
$graphConfig = @{
    TenantId     = "11111111-1111-1111-1111-111111111111"  # Replace with your tenant ID
    ClientId     = "22222222-2222-2222-2222-222222222222"  # Replace with your app registration client ID
    ClientSecret = "YourClientSecretValue"                 # Replace with your app registration client secret
}

# Ensure the required modules are installed
$requiredModules = @("Microsoft.Graph.Authentication", "Microsoft.Graph.Identity.DirectoryManagement")
foreach ($module in $requiredModules) {
    if (-not (Get-Module -Name $module -ListAvailable)) {
        Write-Host "Installing required module: $module" -ForegroundColor Yellow
        Install-Module -Name $module -Scope CurrentUser -Force
    }
}

# Script path - make sure this points to the correct location
$scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Create-EntraIDGroup.ps1"

# Example 1: Create a Security Group (default type)
Write-Host "Example 1: Creating a Security Group" -ForegroundColor Cyan
$securityGroupParams = @{
    DisplayName  = "Finance Security Group"
    Description  = "Security group for the Finance department"
    MailNickname = "FinanceSecurity"
    # GroupType defaults to "Security" if not specified
}

& $scriptPath `
    -TenantId $graphConfig.TenantId `
    -ClientId $graphConfig.ClientId `
    -ClientSecret $graphConfig.ClientSecret `
    @securityGroupParams `
    -Verbose

# Example 2: Create a Microsoft 365 Group
Write-Host "`nExample 2: Creating a Microsoft 365 Group" -ForegroundColor Cyan
$m365GroupParams = @{
    DisplayName  = "Marketing Team"
    Description  = "Microsoft 365 group for Marketing department"
    MailNickname = "MarketingTeam"
    GroupType    = "Microsoft365"
    Visibility   = "Public"  # Can be "Public" or "Private"
    MemberUserPrincipalNames = @("user1@contoso.com", "user2@contoso.com")
}

& $scriptPath `
    -TenantId $graphConfig.TenantId `
    -ClientId $graphConfig.ClientId `
    -ClientSecret $graphConfig.ClientSecret `
    @m365GroupParams `
    -Verbose

# Example 3: Create a Security Group that can be assigned to admin roles
Write-Host "`nExample 3: Creating a Security Group assignable to roles" -ForegroundColor Cyan
$roleGroupParams = @{
    DisplayName       = "Global Admin Group"
    Description       = "Security group for Global Administrators"
    MailNickname      = "GlobalAdmins"
    GroupType         = "Security"
    IsAssignableToRole = $true
}

& $scriptPath `
    -TenantId $graphConfig.TenantId `
    -ClientId $graphConfig.ClientId `
    -ClientSecret $graphConfig.ClientSecret `
    @roleGroupParams `
    -Verbose

# Example 4: Create a Mail-Enabled Security Group
Write-Host "`nExample 4: Creating a Mail-Enabled Security Group" -ForegroundColor Cyan
$mailSecGroupParams = @{
    DisplayName  = "IT Support Team"
    Description  = "Mail-enabled security group for IT Support team"
    MailNickname = "ITSupport"
    GroupType    = "MailEnabledSecurity"
    OwnerUserPrincipalNames = @("admin@contoso.com")
}

& $scriptPath `
    -TenantId $graphConfig.TenantId `
    -ClientId $graphConfig.ClientId `
    -ClientSecret $graphConfig.ClientSecret `
    @mailSecGroupParams `
    -Verbose

<#
# Important Notes:
# 1. Before running this script, ensure you have:
#    - Created an app registration in Entra ID (Azure AD)
#    - Given it appropriate permissions:
#      * Group.Create
#      * Group.ReadWrite.All
#      * Directory.ReadWrite.All
#      * User.ReadWrite.All (for adding members/owners)
#    - Granted admin consent for these permissions
#    - Created a client secret
#
# 2. Replace the placeholder values:
#    - TenantId: Your Entra ID tenant ID
#    - ClientId: Your app registration's client ID
#    - ClientSecret: Your app registration's client secret
#    - User principal names: Valid users in your tenant
#>
