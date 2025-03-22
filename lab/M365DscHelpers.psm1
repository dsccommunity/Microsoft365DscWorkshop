function Get-M365DscNotInDesiredStateResource
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [object]$DscState,

        [Parameter()]
        [switch]$ReturnAllProperties
    )

    $result = foreach ($resource in $DscState.ResourcesNotInDesiredState)
    {
        $FilterXML = @"
<QueryList>
    <Query Id="0" Path="M365DSC">
    <Select Path="M365DSC">*[System[Provider[@Name='MSFT_$($resource.ResourceName)'] and (EventID=1)]]</Select>
    </Query>
</QueryList>
"@
        $event = Get-WinEvent -FilterXml $FilterXML -MaxEvents 1

        $data = $event.Properties[0].Value -replace '<>', ''
        $xml = [xml]$data

        $params = if ($ReturnAllProperties)
        {
            $xml.M365DSCEvent.DesiredValues.Param
        }
        else
        {
            $xml.M365DSCEvent.ConfigurationDrift.ParametersNotInDesiredState.Param
        }

        @{
            ResourceName   = $resource.ResourceName
            ResourceId     = ($resource.InstanceName -split '::\[')[0]
            InDesiredState = $false
            Parameters     = foreach ($param in $params)
            {
                [ordered]@{
                    Name         = $param.Name
                    DesiredValue = if ($ReturnAllProperties)
                    {
                        $param.'#text'
                    }
                    else
                    {
                        $param.DesiredValue
                    }
                    CurrentValue = if ($ReturnAllProperties)
                    {
                        if ($xml.M365DSCEvent.CurrentValues.Param.Where({ $_.Name -eq $param.Name }))
                        {
                            $xml.M365DSCEvent.CurrentValues.Param.Where({ $_.Name -eq $param.Name }).'#text'
                        }
                        else
                        {
                            'NA'
                        }
                    }
                    else
                    {
                        $param.CurrentValue
                    }
                }
            }
        }
    }

    $result
}

function Get-M365DscInDesiredStateResource
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [object]$DscState,

        [Parameter()]
        [switch]$ReturnAllProperties
    )

    $result = foreach ($resource in $DscState.ResourcesInDesiredState)
    {
        $FilterXML = @"
<QueryList>
    <Query Id="0" Path="M365DSC">
    <Select Path="M365DSC">*[System[Provider[@Name='MSFT_$($resource.ResourceName)'] and (EventID=2)]]</Select>
    </Query>
</QueryList>
"@
        $xml = $null
        if ($ReturnAllProperties)
        {
            $event = Get-WinEvent -FilterXml $FilterXML -MaxEvents 1 -ErrorAction SilentlyContinue
        }

        if ($event)
        {
            $data = $event.Properties[0].Value -replace '<>', ''
            $xml = [xml]$data
        }

        @{
            ResourceName   = $resource.ResourceName
            ResourceId     = ($resource.InstanceName -split '::\[')[0]
            InDesiredState = $true
            Parameters     = foreach ($param in $xml.M365DSCEvent.DesiredValues.Param)
            {
                [ordered]@{
                    Name         = $param.Name
                    CurrentValue = $param.'#text'
                    DesiredValue = $param.'#text'
                }
            }
        }
    }

    $result
}

function Get-M365DscState
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]$ReturnAllProperties
    )

    $dscState = Test-DscConfiguration -Detailed
    $data = if ($dscState.InDesiredState)
    {
        Get-M365DscInDesiredStateResource -DscState $dscState -ReturnAllProperties:$ReturnAllProperties
    }
    else
    {
        Get-M365DscInDesiredStateResource -DscState $dscState -ReturnAllProperties:$ReturnAllProperties
        Get-M365DscNotInDesiredStateResource -DscState $dscState -ReturnAllProperties:$ReturnAllProperties
    }

    $data
}

function Write-M365DscStatusEvent
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]$ReturnAllProperties,

        [Parameter()]
        [switch]$PassThru
    )

    $dscResources = Get-M365DscState -ReturnAllProperties:$ReturnAllProperties

    $inDesiredState = -not [bool]($dscResources | Where-Object { -not $_.InDesiredState })
    $resourcesInDesiredState = @($dscResources | Where-Object { $_.InDesiredState })
    $resourcesNotInDesiredState = @($dscResources | Where-Object { -not $_.InDesiredState })

    $sb = [System.Text.StringBuilder]::new()
    if ($inDesiredState)
    {
        [void]$sb.Append(@"
DSC has not reported any resources that are not in the desired state.
The command used was: '`$DscState = Test-DscConfiguration -Verbose -Detailed'

These $($resourcesInDesiredState.Count) resource(s) are in desired state.

"@)

        [void]$sb.Append(($resourcesInDesiredState | ConvertTo-Yaml))

    }
    else
    {
        [void]$sb.Append(@"
DSC reports resources that are not in the desired state.
The command used was: '`$DscState = Test-DscConfiguration -Verbose -Detailed'

There are $($resourcesInDesiredState.Count) resource(s) in desired state and $($resourcesNotInDesiredState.Count) which is / are not.

The following resource(s) are not in the desired state:

"@)

        [void]$sb.Append(($resourcesNotInDesiredState | ConvertTo-Yaml))

        [void]$sb.AppendLine()
        [void]$sb.AppendLine(@"

These $($resourcesInDesiredState.Count) resource(s) are in desired state:

"@)

        [void]$sb.Append(($resourcesInDesiredState | ConvertTo-Yaml))
    }

    $eventParam = @{
        LogName = 'M365DSC'
        Source  = 'Microsoft365DSC'
        Message = $sb.ToString()
    }
    if ($inDesiredState)
    {
        $eventParam.Add('EntryType', 'Information')
        $eventParam.Add('EventId', 1000)
    }
    else
    {
        $eventParam.Add('EntryType', 'Warning')
        $eventParam.Add('EventId', 1001)
    }

    if (-not [System.Diagnostics.EventLog]::SourceExists('Microsoft365DSC'))
    {
        [System.Diagnostics.EventLog]::CreateEventSource('Microsoft365DSC', 'M365DSC')
    }

    Write-EventLog @eventParam

    if ($PassThru)
    {
        [pscustomobject]@{
            InDesiredState             = $inDesiredState
            ResourcesInDesiredState    = $resourcesInDesiredState
            ResourcesNotInDesiredState = $resourcesNotInDesiredState
        }
    }
}

function New-M365TestUser
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$Count = 1,

        [Parameter()]
        [string]$NamePrefix = 'TestUser',

        [Parameter()]
        [string]$Domain,

        [Parameter(Mandatory = $true)]
        [SecureString]$Password,

        [Parameter()]
        [string]$Department = 'Test Users',

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$EnableMailbox,

        [Parameter()]
        [string[]]$Roles
    )

    try
    {
        # Ensure we're connected to Microsoft Graph
        try
        {
            Get-MgContext -ErrorAction Stop | Out-Null
        }
        catch
        {
            throw "Not connected to Microsoft Graph. Please connect using Connect-MgGraph -Scopes 'User.ReadWrite.All' first."
        }

        $createdUsers = @()

        for ($i = 1; $i -le $Count; $i++)
        {
            $userName = "$NamePrefix$i"
            # Get domain from parameter or default tenant domain
            $userDomain = $Domain
            if (-not $userDomain)
            {
                $tenantDomain = Get-MgOrganization | Select-Object -ExpandProperty VerifiedDomains | Where-Object { $_.IsDefault } | Select-Object -ExpandProperty Name
                if (-not $tenantDomain)
                {
                    throw 'No default domain found in tenant and no domain specified'
                }
                $userDomain = $tenantDomain
            }
            $userPrincipalName = "$userName@$userDomain"

            # Check if user already exists
            $existingUser = Get-MgUser -Filter "userPrincipalName eq '$userPrincipalName'" -ErrorAction SilentlyContinue
            if ($existingUser)
            {
                if ($Force)
                {
                    Remove-MgUser -UserId $existingUser.Id
                }
                else
                {
                    Write-Warning "User $userPrincipalName already exists. Use -Force to replace."
                    continue
                }
            }

            # Create new user
            $params = @{
                DisplayName       = $userName
                UserPrincipalName = $userPrincipalName
                AccountEnabled    = $true
                PasswordProfile   = @{
                    Password                      = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
                    ForceChangePasswordNextSignIn = $false
                }
                MailNickname      = $userName
                Department        = $Department
            }

            $newUser = New-MgUser @params
            $createdUsers += $newUser
            Write-Verbose "Created user: $userPrincipalName"

            # Assign roles if specified
            if ($Roles)
            {
                foreach ($roleName in $Roles)
                {
                    try
                    {
                        # Get the role definition
                        $role = Get-MgDirectoryRole -Filter "DisplayName eq '$roleName'" -ErrorAction Stop
                        if (-not $role)
                        {
                            # Role might not be activated yet, try to activate it
                            $roleTemplate = Get-MgDirectoryRoleTemplate -Filter "DisplayName eq '$roleName'" -ErrorAction Stop
                            if ($roleTemplate)
                            {
                                $role = New-MgDirectoryRole -RoleTemplateId $roleTemplate.Id -ErrorAction Stop
                            }
                            else
                            {
                                Write-Warning "Role template not found for role: $roleName"
                                continue
                            }
                        }

                        # Create role assignment
                        $params = @{
                            '@odata.type'  = '#microsoft.graph.directoryRole'
                            RoleId         = $role.Id
                            PrincipalId    = $newUser.Id
                            DirectoryScope = '/'
                        }
                        New-MgDirectoryRoleMemberByRef -DirectoryRoleId $role.Id -BodyParameter @{ '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$($newUser.Id)" } -ErrorAction Stop
                        Write-Verbose "Assigned role '$roleName' to user: $userPrincipalName"
                    }
                    catch
                    {
                        Write-Warning "Error assigning role '$roleName' to $userPrincipalName : $_"
                    }
                }
            }

            if ($EnableMailbox)
            {
                try
                {
                    # Ensure Exchange Online PowerShell is connected
                    try
                    {
                        Get-EXOMailbox -Identity $userPrincipalName -ErrorAction Stop | Out-Null
                    }
                    catch
                    {
                        throw 'Not connected to Exchange Online. Please connect using Connect-ExchangeOnline first.'
                    }

                    # Enable mailbox for the user
                    Enable-Mailbox -Identity $userPrincipalName -ErrorAction Stop
                    Write-Verbose "Enabled mailbox for user: $userPrincipalName"
                }
                catch
                {
                    Write-Warning "Error enabling mailbox for $userPrincipalName : $_"
                }
            }
        }

        return $createdUsers
    }
    catch
    {
        Write-Error "Error creating test users: $_"
    }
}

function Get-M365TestUser
{
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName = 'Filter')]
        [string]$NamePattern = 'TestUser*',

        [Parameter(ParameterSetName = 'Name')]
        [string]$Name
    )

    try
    {
        # Ensure we're connected to Microsoft Graph
        try
        {
            Get-MgContext -ErrorAction Stop | Out-Null
        }
        catch
        {
            throw "Not connected to Microsoft Graph. Please connect using Connect-MgGraph -Scopes 'User.ReadWrite.All' first."
        }

        $users = if ($PSCmdlet.ParameterSetName -eq 'Filter')
        {
            Get-MgUser -All | Where-Object {
                $_.DisplayName -like $NamePattern -or
                $_.UserPrincipalName -like $NamePattern
            }
        }
        else
        {
            Get-MgUser -Filter "DisplayName eq '$Name' or UserPrincipalName eq '$Name'"
        }

        return $users
    }
    catch
    {
        Write-Error "Error getting test users: $_"
    }
}

function Remove-M365TestUser
{
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'ByObject')]
        [Microsoft.Graph.PowerShell.Models.MicrosoftGraphUser]$User,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ByPattern')]
        [string]$NamePattern
    )

    begin
    {
        # Ensure we're connected to Microsoft Graph
        try
        {
            Get-MgContext -ErrorAction Stop | Out-Null
        }
        catch
        {
            throw "Not connected to Microsoft Graph. Please connect using Connect-MgGraph -Scopes 'User.ReadWrite.All' first."
        }
    }

    process
    {
        try
        {
            if ($PSCmdlet.ParameterSetName -eq 'ByPattern')
            {
                $users = Get-M365TestUser -NamePattern $NamePattern
                foreach ($u in $users)
                {
                    if ($PSCmdlet.ShouldProcess($u.UserPrincipalName, 'Remove user'))
                    {
                        Remove-MgUser -UserId $u.Id
                        Write-Verbose "Removed user: $($u.UserPrincipalName)"
                    }
                }
                return $users
            }
            else
            {
                if ($PSCmdlet.ShouldProcess($User.UserPrincipalName, 'Remove user'))
                {
                    Remove-MgUser -UserId $User.Id
                    Write-Verbose "Removed user: $($User.UserPrincipalName)"
                }
                return $User
            }
        }
        catch
        {
            Write-Error "Error removing user: $_"
        }
    }
}

function Add-M365TestUserToAzDevOps
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Microsoft.Graph.PowerShell.Models.MicrosoftGraphUser]$User,

        [Parameter(Mandatory = $true)]
        [string]$ProjectUrl,

        [Parameter()]
        [string]$Team,

        [Parameter(Mandatory = $true)]
        [string]$PersonalAccessToken
    )

    begin
    {
        # Parse Azure DevOps URL
        try
        {
            $uri = [System.Uri]$ProjectUrl
            $pathSegments = $uri.AbsolutePath.Split('/', [StringSplitOptions]::RemoveEmptyEntries)

            if ($pathSegments.Length -lt 2)
            {
                throw 'Invalid Azure DevOps project URL. Expected format: https://dev.azure.com/{organization}/{project}'
            }

            $organization = $pathSegments[0]
            $project = $pathSegments[1]
        }
        catch
        {
            throw "Failed to parse Azure DevOps project URL: $_"
        }

        # Create authorization header using PAT
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$PersonalAccessToken"))
        $headers = @{
            Authorization  = "Basic $base64AuthInfo"
            'Content-Type' = 'application/json'
        }
    }

    process
    {
        try
        {
            # Set team name
            $teamName = if ($Team)
            {
                $Team
            }
            else
            {
                "$project Team"
            }

            # Add member to organization using member entitlement management API
            Write-Verbose 'Adding member to organization...'
            $addMemberUrl = "https://vsaex.dev.azure.com/$organization/_apis/UserEntitlements?api-version=7.1-preview.3"

            $memberBody = @{
                accessLevel = @{
                    accountLicenseType = 'express'  # Basic access level
                }
                user        = @{
                    principalName = $User.UserPrincipalName
                    subjectKind   = 'user'
                }
            } | ConvertTo-Json

            $result = Invoke-RestMethod -Uri $addMemberUrl -Headers $headers -Method Post -Body $memberBody -ErrorAction Stop
            Write-Verbose 'Successfully added member to organization'

            # Now add to project if specified
            if ($project)
            {
                Write-Verbose 'Adding member to project...'
                $addProjectMemberUrl = "https://dev.azure.com/$organization/_apis/projects/$project/teams/$($project)%20Team/members?api-version=7.1-preview.3"

                $projectMemberBody = @{
                    user = @{
                        id            = $User.Id
                        principalName = $User.UserPrincipalName
                        origin        = 'aad'
                    }
                } | ConvertTo-Json

                try
                {
                    $projectResult = Invoke-RestMethod -Uri $addProjectMemberUrl -Headers $headers -Method Post -Body $projectMemberBody -ErrorAction Stop
                    Write-Verbose 'Successfully added member to project team'
                }
                catch
                {
                    Write-Warning "Unable to add user to project team: $_"
                    # Don't throw error since user was added to org successfully
                }
            }

            if ($null -eq $result)
            {
                throw 'Azure DevOps API returned null response'
            }

            Write-Verbose "Added user $($User.UserPrincipalName) to Azure DevOps organization '$organization'"

            # Return custom object with operation details
            [PSCustomObject]@{
                User         = $User
                Organization = $organization
                Project      = $project
                Team         = if ($Team)
                {
                    $Team
                }
                else
                {
                    "$project Team"
                }
                Status       = 'Added'
            }
        }
        catch
        {
            $errorMessage = if ($_.ErrorDetails.Message)
            {
                try
                {
                    $errorJson = $_.ErrorDetails.Message | ConvertFrom-Json
                    if ($errorJson.message)
                    {
                        $errorJson.message
                    }
                    elseif ($errorJson.value)
                    {
                        $errorJson.value | ForEach-Object { $_.message } | Join-String -Separator '; '
                    }
                    else
                    {
                        $_.ErrorDetails.Message
                    }
                }
                catch
                {
                    $_.ErrorDetails.Message
                }
            }
            else
            {
                $_.Exception.Message
            }

            # Try to get more detailed error info
            $detailedError = if ($_.Exception.Response)
            {
                try
                {
                    $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
                    $reader.BaseStream.Position = 0
                    $reader.ReadToEnd() | ConvertFrom-Json | Select-Object -ExpandProperty message -ErrorAction SilentlyContinue
                }
                catch
                {
                    $errorMessage
                }
            }
            else
            {
                $errorMessage
            }

            Write-Error "Failed to add user $($User.UserPrincipalName) to Azure DevOps project: $detailedError"
            return $null
        }
    }
}

function Wait-DscLocalConfigurationManager
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]
        $DoNotWaitForProcessToFinish
    )

    Write-Verbose 'Checking if LCM is busy.'
    if ((Get-DscLocalConfigurationManager).LCMState -eq 'Busy')
    {
        Write-Host 'LCM is busy, waiting until LCM has finished the job...' -NoNewline
        while ((Get-DscLocalConfigurationManager).LCMState -eq 'Busy')
        {
            Start-Sleep -Seconds 1
            Write-Host . -NoNewline
        }
        Write-Host 'done. LCM is no longer busy.'
    }
    else
    {
        Write-Verbose 'LCM is not busy'
    }

    if (-not $DoNotWaitForProcessToFinish)
    {
        $lcmProcessId = (Get-PSHostProcessInfo | Where-Object { $_.AppDomainName -eq 'DscPsPluginWkr_AppDomain' -and $_.ProcessName -eq 'WmiPrvSE' }).ProcessId
        if ($lcmProcessId)
        {
            Write-Host "LCM process with ID $lcmProcessId is still running, waiting for the process to exit..." -NoNewline
            $lcmProcess = Get-Process -Id $lcmProcessId
            while (-not $lcmProcess.HasExited)
            {
                Write-Host . -NoNewline
                Start-Sleep -Seconds 2
            }
            Write-Host 'done. Process existed.'
        }
        else
        {
            Write-Verbose 'LCM process was not running.'
        }
    }
}

function Add-M365TestUserToAzDevOps
{
    <#
    .SYNOPSIS
    Adds a Microsoft 365 test user to an Azure DevOps project.

    .DESCRIPTION
    This function adds a Microsoft 365 user to an Azure DevOps organization and project. It handles:
    - Adding the user to the Azure DevOps organization
    - Setting the user's access level
    - Adding the user to the project's Contributors group
    - Adding the user to a specific team or the project's default team

    The function includes retry logic to handle async operations and proper error handling.

    .PARAMETER User
    The Microsoft Graph user object to add to Azure DevOps.

    .PARAMETER ProjectUrl
    The URL of the Azure DevOps project. Format: https://dev.azure.com/{organization}/{project}

    .PARAMETER Team
    Optional. The name of the team to add the user to. If not specified, adds to the project's default team.

    .PARAMETER PersonalAccessToken
    The Azure DevOps Personal Access Token with appropriate permissions.

    .PARAMETER AccessLevel
    Optional. The access level to assign to the user. Valid values are 'express', 'stakeholder', or 'basic'.
    Default is 'basic'.

    .PARAMETER RetryCount
    Optional. The number of times to retry operations that might fail due to async processing.
    Default is 3.

    .PARAMETER RetryWaitSeconds
    Optional. The number of seconds to wait between retry attempts.
    Default is 5.

    .EXAMPLE
    $user = Get-MgUser -UserPrincipalName "testuser@contoso.com"
    $user | Add-M365TestUserToAzDevOps -ProjectUrl "https://dev.azure.com/contoso/project1" -PersonalAccessToken "pat_token"

    Adds the specified user to the Azure DevOps project with basic access level.

    .EXAMPLE
    $user | Add-M365TestUserToAzDevOps -ProjectUrl "https://dev.azure.com/contoso/project1" -Team "Dev Team" -AccessLevel "stakeholder" -PersonalAccessToken "pat_token"

    Adds the user to a specific team with stakeholder access level.

    .NOTES
    Requires:
    - Azure DevOps Personal Access Token with appropriate permissions
    - Microsoft.Graph.Users module
    - User must exist in Azure AD that's connected to Azure DevOps

    .LINK
    https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/add-organization-users
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Microsoft.Graph.PowerShell.Models.MicrosoftGraphUser]$User,

        [Parameter(Mandatory = $true)]
        [string]$ProjectUrl,

        [Parameter(Mandatory = $true)]
        [string]$PersonalAccessToken,

        [Parameter()]
        [ValidateSet('express', 'stakeholder', 'basic')]
        [string]$AccessLevel = 'basic',

        [Parameter()]
        [int]$RetryCount = 3,

        [Parameter()]
        [int]$RetryWaitSeconds = 5
    )

    begin
    {
        # Parse Azure DevOps URL
        try
        {
            $uri = [System.Uri]$ProjectUrl
            $pathSegments = $uri.AbsolutePath.Split('/', [StringSplitOptions]::RemoveEmptyEntries)

            if ($pathSegments.Length -lt 2)
            {
                throw 'Invalid Azure DevOps project URL. Expected format: https://dev.azure.com/{organization}/{project}'
            }

            $organization = $pathSegments[0]
            $project = $pathSegments[1]
        }
        catch
        {
            throw "Failed to parse Azure DevOps project URL: $_"
        }

        # Create authorization header using PAT
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$PersonalAccessToken"))
        $headers = @{
            Authorization  = "Basic $base64AuthInfo"
            'Content-Type' = 'application/json'
        }

        function Wait-UserAvailable
        {
            param (
                [string]$UserPrincipalName,
                [string]$Organization
            )

            Write-Verbose "Waiting for user $UserPrincipalName to become available..."
            for ($i = 1; $i -le $RetryCount; $i++)
            {
                try
                {
                    $checkUrl = [uri]::EscapeUriString("https://vssps.dev.azure.com/$organization/_apis/graph/users?api-version=7.1-preview.1")
                    $checkResult = Invoke-RestMethod -Uri $checkUrl -Headers $headers -Method Get -ErrorAction Stop
                    if ($checkResult.value | Where-Object principalName -EQ $UserPrincipalName)
                    {
                        Write-Verbose 'User found in Azure DevOps'
                        return $true
                    }
                    else
                    {
                        Write-Verbose ('Attempt {0}: User not found yet...' -f $i)
                    }
                }
                catch
                {
                    Write-Verbose ('Attempt {0}: User not found yet...' -f $i)
                }
                Start-Sleep -Seconds $RetryWaitSeconds
            }
            return $false
        }
    }

    process
    {
        try
        {
            # First check if user already exists in organization
            Write-Verbose 'Checking if user exists in organization...'
            $filterQuery = [uri]::EscapeDataString("name eq '$($User.UserPrincipalName)'")
            $userCheckUrl = "https://vsaex.dev.azure.com/$organization/_apis/UserEntitlements?api-version=7.1-preview.3&filter=$filterQuery"
            $existingUser = $null

            try
            {
                $existingEntitlement = Invoke-RestMethod -Uri $userCheckUrl -Headers $headers -Method Get -ErrorAction Stop
                $existingUser = $existingEntitlement.members | Where-Object { $_.user.principalName -eq $User.UserPrincipalName }
            }
            catch
            {
                Write-Verbose "No existing user found: $_"
            }

            if ($existingUser)
            {
                Write-Verbose "User already exists in organization with access level: $($existingUser.accessLevel.accountLicenseType)"
            }
            else
            {
                # Add member to organization using member entitlement management API
                Write-Verbose "Adding member to organization with $AccessLevel access..."
                $addMemberUrl = "https://vsaex.dev.azure.com/$organization/_apis/UserEntitlements?api-version=7.1-preview.3"

                $memberBody = @{
                    accessLevel = @{
                        accountLicenseType = $AccessLevel
                    }
                    user        = @{
                        principalName = $User.UserPrincipalName
                        subjectKind   = 'user'
                        origin        = 'aad'
                        originId      = $User.Id
                    }
                } | ConvertTo-Json

                $result = Invoke-RestMethod -Uri $addMemberUrl -Headers $headers -Method Post -Body $memberBody -ErrorAction Stop
                if ($result.isSuccess -eq $false)
                {
                    throw "Failed to add user to organization: '$($result.operationResult.errors.value)'"
                }
                Write-Verbose 'Successfully added member to organization'

                # Wait for user to be fully provisioned
                Start-Sleep -Seconds $RetryWaitSeconds
            }

            # Wait for user to become available in Azure DevOps
            if (-not (Wait-UserAvailable -UserPrincipalName $User.UserPrincipalName -Organization $organization))
            {
                throw "User was not found in Azure DevOps after $RetryCount attempts"
            }

            # Now add to project
            if ($project)
            {
                Write-Verbose 'Adding member to project...'

                # First get project info
                Write-Verbose 'Getting project details...'
                $projectUrl = [uri]::EscapeUriString("https://dev.azure.com/$organization/_apis/projects/$project") + '?api-version=7.1-preview.4'
                $projectInfo = Invoke-RestMethod -Uri $projectUrl -Headers $headers -Method Get -ErrorAction Stop

                # Get the project descriptor
                Write-Verbose 'Getting project descriptor...'
                $descriptorUrl = "https://vssps.dev.azure.com/$organization/_apis/graph/descriptors/$($projectInfo.id)?api-version=7.1-preview.1"
                $descriptor = $null

                for ($i = 1; $i -le $RetryCount; $i++)
                {
                    try
                    {
                        $descriptor = Invoke-RestMethod -Uri $descriptorUrl -Headers $headers -Method Get -ErrorAction Stop
                        break
                    }
                    catch
                    {
                        if ($i -eq $RetryCount)
                        {
                            throw "Failed to get project descriptor after $RetryCount attempts: $_"
                        }
                        Write-Warning ('Attempt {0}: Could not get project descriptor, waiting {1} seconds...' -f $i, $RetryWaitSeconds)
                        Start-Sleep -Seconds $RetryWaitSeconds
                    }
                }

                # Get the user's descriptor
                Write-Verbose 'Getting user descriptor...'
                $userId = if ($existingUser)
                {
                    $existingUser.id
                }
                else
                {
                    $result.operationResult.userId
                }

                $userDescriptorUrl = "https://vssps.dev.azure.com/$organization/_apis/graph/descriptors/$userId"
                $userDescriptor = $null

                for ($i = 1; $i -le $RetryCount; $i++)
                {
                    try
                    {
                        $userDescriptor = Invoke-RestMethod -Uri $userDescriptorUrl -Headers $headers -Method Get -ErrorAction Stop
                        break
                    }
                    catch
                    {
                        if ($i -eq $RetryCount)
                        {
                            throw "Failed to get user descriptor after $RetryCount attempts: $_"
                        }
                        Write-Warning ('Attempt {0}: Could not get user descriptor, waiting {1} seconds...' -f $i, $RetryWaitSeconds)
                        Start-Sleep -Seconds $RetryWaitSeconds
                    }
                }

                # Get project groups using project descriptor
                Write-Verbose 'Getting project groups...'
                $groupsUrl = "https://vssps.dev.azure.com/$organization/_apis/graph/groups?scopeDescriptor=$($descriptor.value)&api-version=7.1-preview.1"
                $projectGroups = Invoke-RestMethod -Uri $groupsUrl -Headers $headers -Method Get -ErrorAction Stop

                # Find the Contributors group
                $contributorsGroup = $projectGroups.value | Where-Object { $_.displayName -eq 'Contributors' }
                if ($contributorsGroup)
                {
                    Write-Verbose "Found Contributors group: $($contributorsGroup.displayName)"

                    # Add user to Contributors group
                    Write-Verbose 'Adding user to Contributors group...'
                    $addToGroupUrl = "https://vssps.dev.azure.com/$organization/_apis/graph/memberships/$($userDescriptor.value)/$($contributorsGroup.descriptor)?api-version=7.1-preview.1"

                    try
                    {
                        $groupResult = Invoke-RestMethod -Uri $addToGroupUrl -Headers $headers -Method Put -ErrorAction Stop
                        Write-Verbose 'Successfully added user to Contributors group'
                    }
                    catch
                    {
                        if ($_.Exception.Response.StatusCode -eq 409)
                        {
                            Write-Verbose 'User is already a member of Contributors group'
                        }
                        else
                        {
                            Write-Warning "Could not add user to Contributors group: $_"
                        }
                    }
                }
                else
                {
                    Write-Warning "Could not find Contributors group for project $project"
                }
            }

            if ($null -eq $groupResult)
            {
                throw 'Azure DevOps API returned null response'
            }

            Write-Verbose "User $($User.UserPrincipalName) is now set up in Azure DevOps organization '$organization'"

            # Return custom object with operation details
            [PSCustomObject]@{
                User         = $User
                Organization = $organization
                Project      = $project
                AccessLevel  = $result.accessLevel.accountLicenseType
                Status       = 'Added'
            }
        }
        catch
        {
            $errorMessage = if ($_.ErrorDetails.Message)
            {
                try
                {
                    $errorJson = $_.ErrorDetails.Message | ConvertFrom-Json
                    if ($errorJson.message)
                    {
                        $errorJson.message
                    }
                    elseif ($errorJson.value)
                    {
                        $errorJson.value | ForEach-Object { $_.message } | Join-String -Separator '; '
                    }
                    else
                    {
                        $_.ErrorDetails.Message
                    }
                }
                catch
                {
                    $_.ErrorDetails.Message
                }
            }
            else
            {
                $_.Exception.Message
            }

            Write-Error "Failed to add user $($User.UserPrincipalName) to Azure DevOps project: $errorMessage"
            return $null
        }
    }
}
