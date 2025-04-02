#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Identity.DirectoryManagement
<#
.SYNOPSIS
    Creates a new group in Entra ID using Microsoft Graph API.

.DESCRIPTION
    This script creates a new group in Entra ID (formerly Azure AD) using Microsoft Graph API.
    It supports creating Microsoft 365 Groups, Security Groups, and Mail-enabled Security Groups.

.PARAMETER TenantId
    The tenant ID where the group will be created.

.PARAMETER ClientId
    The Client/Application ID of the app registration with permissions to create groups.

.PARAMETER ClientSecret
    The Client Secret of the app registration.

.PARAMETER DisplayName
    The display name for the new group.

.PARAMETER Description
    The description for the new group.

.PARAMETER MailNickname
    The mail nickname for the group. Required for all group types.

.PARAMETER GroupType
    The type of group to create. Valid values are "Microsoft365", "Security", or "MailEnabledSecurity".
    Default is "Security".

.PARAMETER MemberUserPrincipalNames
    Optional array of user principal names to add as members to the group.

.PARAMETER OwnerUserPrincipalNames
    Optional array of user principal names to add as owners to the group.

.PARAMETER IsAssignableToRole
    Specifies whether this group can be assigned to an Azure Active Directory role.
    This property can only be set at creation time.

.PARAMETER Visibility
    Specifies the visibility of a Microsoft 365 group. Valid values are "Private" or "Public".

.EXAMPLE
    .\Create-EntraIDGroup.ps1 -TenantId "00000000-0000-0000-0000-000000000000" -ClientId "00000000-0000-0000-0000-000000000000" -ClientSecret "ClientSecretValue" -DisplayName "Marketing Team" -Description "Marketing department team" -MailNickname "MarketingTeam" -GroupType "Microsoft365"

.EXAMPLE
    .\Create-EntraIDGroup.ps1 -TenantId "00000000-0000-0000-0000-000000000000" -ClientId "00000000-0000-0000-0000-000000000000" -ClientSecret "ClientSecretValue" -DisplayName "IT Administrators" -Description "IT Admin security group" -MailNickname "ITAdmins" -GroupType "Security" -IsAssignableToRole $true

.NOTES
    Required Graph API permissions:
    - Group.Create
    - Group.ReadWrite.All
    - Directory.ReadWrite.All

    For adding members and owners:
    - User.ReadWrite.All

    File Name      : Create-EntraIDGroup.ps1
    Author         : Microsoft365 DSC Workshop
    Prerequisite   : PowerShell 5.1 or later
                     Microsoft.Graph PowerShell modules
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $TenantId,

    [Parameter(Mandatory = $true)]
    [string] $ClientId,

    [Parameter(Mandatory = $true)]
    [string] $ClientSecret,

    [Parameter(Mandatory = $true)]
    [string] $DisplayName,

    [Parameter(Mandatory = $false)]
    [string] $Description = '',

    [Parameter(Mandatory = $true)]
    [string] $MailNickname,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Microsoft365', 'Security', 'MailEnabledSecurity')]
    [string] $GroupType = 'Security',

    [Parameter(Mandatory = $false)]
    [string[]] $MemberUserPrincipalNames,

    [Parameter(Mandatory = $false)]
    [string[]] $OwnerUserPrincipalNames,

    [Parameter(Mandatory = $false)]
    [bool] $IsAssignableToRole = $false,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Private', 'Public')]
    [string] $Visibility = 'Private'
)

#region Functions
function Connect-ToGraph
{
    param (
        [Parameter(Mandatory = $true)]
        [string] $TenantId,

        [Parameter(Mandatory = $true)]
        [string] $ClientId,

        [Parameter(Mandatory = $true)]
        [string] $ClientSecret
    )

    try
    {
        # Create authentication token
        $body = @{
            client_id     = $ClientId
            client_secret = $ClientSecret
            scope         = 'https://graph.microsoft.com/.default'
            grant_type    = 'client_credentials'
        }

        # Get OAuth token
        $tokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
        $tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenUrl -Body $body -ContentType 'application/x-www-form-urlencoded'

        # Connect to Microsoft Graph
        Connect-MgGraph -AccessToken $tokenResponse.access_token -NoWelcome

        # Check connection
        $context = Get-MgContext
        if ($null -eq $context)
        {
            throw 'Failed to authenticate to Microsoft Graph API.'
        }

        Write-Verbose 'Successfully connected to Microsoft Graph API.'
        return $true
    }
    catch
    {
        Write-Error "Error connecting to Microsoft Graph: $_"
        return $false
    }
}

function New-EntraGroup
{
    param (
        [Parameter(Mandatory = $true)]
        [string] $DisplayName,

        [Parameter(Mandatory = $true)]
        [string] $Description,

        [Parameter(Mandatory = $true)]
        [string] $MailNickname,

        [Parameter(Mandatory = $true)]
        [string] $GroupType,

        [Parameter(Mandatory = $false)]
        [bool] $IsAssignableToRole,

        [Parameter(Mandatory = $false)]
        [string] $Visibility
    )

    try
    {
        # Prepare group creation parameters based on group type
        $groupParams = @{
            DisplayName     = $DisplayName
            Description     = $Description
            MailNickname    = $MailNickname
            SecurityEnabled = $false
            MailEnabled     = $false
        }

        switch ($GroupType)
        {
            'Microsoft365'
            {
                $groupParams.SecurityEnabled = $false
                $groupParams.MailEnabled = $true
                $groupParams.GroupTypes = @('Unified')
                $groupParams.Visibility = $Visibility
            }
            'Security'
            {
                $groupParams.SecurityEnabled = $true
                $groupParams.MailEnabled = $false
                if ($IsAssignableToRole)
                {
                    $groupParams.IsAssignableToRole = $true
                }
            }
            'MailEnabledSecurity'
            {
                $groupParams.SecurityEnabled = $true
                $groupParams.MailEnabled = $true
            }
        }

        # Create the group
        $newGroup = New-MgGroup @groupParams
        Write-Verbose "Group '$DisplayName' created successfully. Group ID: $($newGroup.Id)"
        return $newGroup
    }
    catch
    {
        Write-Error "Error creating group: $_"
        return $null
    }
}

function Add-GroupMembers
{
    param (
        [Parameter(Mandatory = $true)]
        [string] $GroupId,

        [Parameter(Mandatory = $true)]
        [string[]] $UserPrincipalNames
    )

    try
    {
        foreach ($upn in $UserPrincipalNames)
        {
            $user = Get-MgUser -Filter "userPrincipalName eq '$upn'"
            if ($null -ne $user)
            {
                New-MgGroupMember -GroupId $GroupId -DirectoryObjectId $user.Id
                Write-Verbose "Added user '$upn' as member to group."
            }
            else
            {
                Write-Warning "User '$upn' not found and could not be added as member."
            }
        }
        return $true
    }
    catch
    {
        Write-Error "Error adding members to group: $_"
        return $false
    }
}

function Add-GroupOwners
{
    param (
        [Parameter(Mandatory = $true)]
        [string] $GroupId,

        [Parameter(Mandatory = $true)]
        [string[]] $UserPrincipalNames
    )

    try
    {
        foreach ($upn in $UserPrincipalNames)
        {
            $user = Get-MgUser -Filter "userPrincipalName eq '$upn'"
            if ($null -ne $user)
            {
                New-MgGroupOwner -GroupId $GroupId -DirectoryObjectId $user.Id
                Write-Verbose "Added user '$upn' as owner to group."
            }
            else
            {
                Write-Warning "User '$upn' not found and could not be added as owner."
            }
        }
        return $true
    }
    catch
    {
        Write-Error "Error adding owners to group: $_"
        return $false
    }
}
#endregion

#region Main Script
# Check for Microsoft.Graph modules
$requiredModules = @('Microsoft.Graph.Authentication', 'Microsoft.Graph.Identity.DirectoryManagement')
foreach ($module in $requiredModules)
{
    if (-not (Get-Module -Name $module -ListAvailable))
    {
        Write-Error "Required module '$module' is not installed. Please install it using: Install-Module -Name $module -Scope CurrentUser"
        exit 1
    }
}

# Connect to Microsoft Graph
$connected = Connect-ToGraph -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret
if (-not $connected)
{
    Write-Error 'Failed to connect to Microsoft Graph API. Check your credentials and try again.'
    exit 1
}

# Create the group
Write-Output "Creating group: $DisplayName"
$newGroup = New-EntraGroup -DisplayName $DisplayName -Description $Description -MailNickname $MailNickname `
    -GroupType $GroupType -IsAssignableToRole $IsAssignableToRole -Visibility $Visibility

if ($null -eq $newGroup)
{
    Write-Error 'Failed to create group.'
    exit 1
}

# Add members if specified
if ($MemberUserPrincipalNames -and $MemberUserPrincipalNames.Count -gt 0)
{
    Write-Output 'Adding members to the group...'
    $membersAdded = Add-GroupMembers -GroupId $newGroup.Id -UserPrincipalNames $MemberUserPrincipalNames
    if (-not $membersAdded)
    {
        Write-Warning 'Some members could not be added to the group.'
    }
}

# Add owners if specified
if ($OwnerUserPrincipalNames -and $OwnerUserPrincipalNames.Count -gt 0)
{
    Write-Output 'Adding owners to the group...'
    $ownersAdded = Add-GroupOwners -GroupId $newGroup.Id -UserPrincipalNames $OwnerUserPrincipalNames
    if (-not $ownersAdded)
    {
        Write-Warning 'Some owners could not be added to the group.'
    }
}

# Output results
Write-Output 'Group created successfully!'
Write-Output '-----------------------------'
Write-Output "Group ID:      $($newGroup.Id)"
Write-Output "Display Name:  $($newGroup.DisplayName)"
Write-Output "Description:   $($newGroup.Description)"
Write-Output "Mail Nickname: $($newGroup.MailNickname)"
Write-Output "Group Type:    $GroupType"
if ($GroupType -eq 'Microsoft365')
{
    Write-Output "Visibility:    $Visibility"
}
Write-Output '-----------------------------'

# Disconnect from Microsoft Graph
Disconnect-MgGraph -ErrorAction SilentlyContinue
#endregion
