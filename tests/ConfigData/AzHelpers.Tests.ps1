BeforeAll {
    $requiredModulesPath = (Resolve-Path -Path $PSScriptRoot\..\..\output\RequiredModules).Path
    if ($env:PSModulePath -notlike "*$requiredModulesPath*")
    {
        $env:PSModulePath = $env:PSModulePath + [IO.Path]::PathSeparator + $requiredModulesPath
    }

    $requiredModules = Import-PowerShellDataFile -Path $PSScriptRoot\..\..\RequiredModules.psd1

    # Importing a binary Az or Graph module into a session that already holds it fails with
    # 'Assembly with same name is already loaded'. The build session loads Az before 'TestConfigData'
    # runs, so take whatever is loaded and pin the version only for a session that has none.
    $moduleNames = 'Az.Accounts',
    'Az.Resources',
    'Microsoft.Graph.Authentication',
    'Microsoft.Graph.Applications',
    'Microsoft.Graph.Identity.DirectoryManagement',
    'ExchangeOnlineManagement'

    foreach ($moduleName in $moduleNames)
    {
        if (Get-Module -Name $moduleName)
        {
            continue
        }

        $requiredVersion = $requiredModules[$moduleName]
        if ($requiredVersion -is [hashtable])
        {
            $requiredVersion = $requiredVersion.Version
        }

        if ($requiredVersion -and $requiredVersion -ne 'latest')
        {
            Import-Module -Name $moduleName -RequiredVersion $requiredVersion
        }
        else
        {
            Import-Module -Name $moduleName
        }
    }

    Import-Module -Name $PSScriptRoot\..\..\lab\AzHelpers.psm1 -Force
}

Describe 'Connect-M365DscAzure' -Tag Integration {
    BeforeEach {
        Mock -CommandName Connect-AzAccount -ModuleName AzHelpers -MockWith {
            [pscustomobject]@{
                Context = [pscustomobject]@{
                    Subscription = [pscustomobject]@{
                        Name = 'Configured subscription'
                        Id   = '9522bd96-d34f-4910-9667-0517ab5dc595'
                    }
                    Account      = [pscustomobject]@{
                        Id = 'test-application'
                    }
                }
            }
        }
        Mock -CommandName Get-AzAccessToken -ModuleName AzHelpers -MockWith {
            $token = [securestring]::new()
            foreach ($character in 'token'.ToCharArray())
            {
                $token.AppendChar($character)
            }
            $token.MakeReadOnly()

            [pscustomobject]@{
                Token = $token
            }
        }
        Mock -CommandName Connect-MgGraph -ModuleName AzHelpers
        Mock -CommandName Get-MgContext -ModuleName AzHelpers -MockWith {
            [pscustomobject]@{
                TenantId = 'b246c1af-87ab-41d8-9812-83cd5ff534cb'
                ClientId = 'test-application'
            }
        }
    }

    It 'Should select the configured subscription when using an application secret' {
        $secret = [securestring]::new()
        foreach ($character in 'secret'.ToCharArray())
        {
            $secret.AppendChar($character)
        }
        $secret.MakeReadOnly()

        Connect-M365DscAzure `
            -TenantId 'b246c1af-87ab-41d8-9812-83cd5ff534cb' `
            -SubscriptionId '9522bd96-d34f-4910-9667-0517ab5dc595' `
            -ServicePrincipalId 'test-application' `
            -ServicePrincipalSecret $secret

        Should -Invoke -CommandName Connect-AzAccount -ModuleName AzHelpers -Times 1 -Exactly -ParameterFilter {
            $Tenant -eq 'b246c1af-87ab-41d8-9812-83cd5ff534cb' -and
            $Subscription -eq '9522bd96-d34f-4910-9667-0517ab5dc595' -and
            $ServicePrincipal
        }
    }

    It 'Should select the configured subscription when using a certificate' {
        Connect-M365DscAzure `
            -TenantId 'b246c1af-87ab-41d8-9812-83cd5ff534cb' `
            -SubscriptionId '9522bd96-d34f-4910-9667-0517ab5dc595' `
            -ServicePrincipalId 'test-application' `
            -CertificateThumbprint '0123456789ABCDEF0123456789ABCDEF01234567'

        Should -Invoke -CommandName Connect-AzAccount -ModuleName AzHelpers -Times 1 -Exactly -ParameterFilter {
            $Tenant -eq 'b246c1af-87ab-41d8-9812-83cd5ff534cb' -and
            $Subscription -eq '9522bd96-d34f-4910-9667-0517ab5dc595' -and
            $ApplicationId -eq 'test-application' -and
            $CertificateThumbprint -eq '0123456789ABCDEF0123456789ABCDEF01234567'
        }
    }
}

Describe 'Test-M365DscExchangeOnlineLicense' -Tag Integration {
    BeforeEach {
        Mock -CommandName Get-MgContext -ModuleName AzHelpers -MockWith {
            [pscustomobject]@{ TenantId = 'b246c1af-87ab-41d8-9812-83cd5ff534cb' }
        }
        Mock -CommandName Get-MgServicePrincipal -ModuleName AzHelpers -MockWith {
            [pscustomobject]@{ AppId = '00000002-0000-0ff1-ce00-000000000000'; AccountEnabled = $true }
        }
        Mock -CommandName Get-MgSubscribedSku -ModuleName AzHelpers -MockWith {
            [pscustomobject]@{
                ServicePlans = @(
                    [pscustomobject]@{ ServicePlanName = 'EXCHANGE_S_FOUNDATION'; ProvisioningStatus = 'Success' }
                    [pscustomobject]@{ ServicePlanName = 'EXCHANGE_S_ENTERPRISE'; ProvisioningStatus = 'Success' }
                )
            }
        }
    }

    It 'Should report a licensed tenant' {
        Test-M365DscExchangeOnlineLicense | Should -BeTrue
    }

    It 'Should report an unlicensed tenant when the Exchange Online service principal is disabled' {
        # This is the state of a tenant whose Microsoft 365 subscription has lapsed.
        Mock -CommandName Get-MgServicePrincipal -ModuleName AzHelpers -MockWith {
            [pscustomobject]@{ AppId = '00000002-0000-0ff1-ce00-000000000000'; AccountEnabled = $false }
        }

        Test-M365DscExchangeOnlineLicense | Should -BeFalse
    }

    It "Should report an unlicensed tenant when only 'EXCHANGE_S_FOUNDATION' is provisioned" {
        # 'EXCHANGE_S_FOUNDATION' ships with almost every SKU and grants no Exchange Online mailbox.
        Mock -CommandName Get-MgSubscribedSku -ModuleName AzHelpers -MockWith {
            [pscustomobject]@{
                ServicePlans = @(
                    [pscustomobject]@{ ServicePlanName = 'EXCHANGE_S_FOUNDATION'; ProvisioningStatus = 'Success' }
                )
            }
        }

        Test-M365DscExchangeOnlineLicense | Should -BeFalse
    }
}

Describe 'Connect-M365Dsc' -Tag Integration {
    BeforeEach {
        Mock -CommandName Disconnect-M365Dsc -ModuleName AzHelpers
        Mock -CommandName Connect-M365DscAzure -ModuleName AzHelpers
        Mock -CommandName Connect-M365DscExchangeOnline -ModuleName AzHelpers
    }

    It 'Should connect to Exchange Online when the tenant is licensed for it' {
        Mock -CommandName Test-M365DscExchangeOnlineLicense -ModuleName AzHelpers -MockWith { $true }

        Connect-M365Dsc -TenantId 'b246c1af-87ab-41d8-9812-83cd5ff534cb' -TenantName 'contoso.onmicrosoft.com'

        Should -Invoke -CommandName Connect-M365DscExchangeOnline -ModuleName AzHelpers -Times 1 -Exactly
    }

    It 'Should fail when Exchange Online is expected but the tenant is not licensed for it' {
        Mock -CommandName Test-M365DscExchangeOnlineLicense -ModuleName AzHelpers -MockWith { $false }

        { Connect-M365Dsc -TenantId 'b246c1af-87ab-41d8-9812-83cd5ff534cb' -TenantName 'contoso.onmicrosoft.com' } |
            Should -Throw "*is not licensed for Exchange Online*"

        Should -Invoke -CommandName Connect-M365DscAzure -ModuleName AzHelpers -Times 1 -Exactly
        Should -Invoke -CommandName Connect-M365DscExchangeOnline -ModuleName AzHelpers -Times 0 -Exactly
    }

    It 'Should not test the license when Exchange Online is skipped by the configuration' {
        Mock -CommandName Test-M365DscExchangeOnlineLicense -ModuleName AzHelpers -MockWith { $true }

        Connect-M365Dsc -TenantId 'b246c1af-87ab-41d8-9812-83cd5ff534cb' -TenantName 'contoso.onmicrosoft.com' -SkipExchangeOnline

        Should -Invoke -CommandName Test-M365DscExchangeOnlineLicense -ModuleName AzHelpers -Times 0 -Exactly
        Should -Invoke -CommandName Connect-M365DscExchangeOnline -ModuleName AzHelpers -Times 0 -Exactly
    }
}

Describe 'Disconnect-M365Dsc' -Tag Integration {
    BeforeEach {
        Mock -CommandName Test-M365DscExchangeOnlineConnection -ModuleName AzHelpers -MockWith { $false }
        Mock -CommandName Disconnect-MgGraph -ModuleName AzHelpers
        Mock -CommandName Clear-AzContext -ModuleName AzHelpers
    }

    It 'Should clear the Azure context when Disconnect-AzAccount hits the MSAL assembly conflict' {
        # Verbatim error of Az.Accounts 5.3.2 running next to Microsoft.Graph.Authentication 2.35.1.
        Mock -CommandName Disconnect-AzAccount -ModuleName AzHelpers -MockWith {
            throw [System.MissingMethodException]::new("Method not found: 'Void Microsoft.Identity.Client.Extensions.Msal.MsalCacheHelper.RegisterCache(Microsoft.Identity.Client.ITokenCache)'.")
        }

        Disconnect-M365Dsc -WarningAction SilentlyContinue

        Should -Invoke -CommandName Clear-AzContext -ModuleName AzHelpers -Times 1 -Exactly -ParameterFilter {
            $Scope -eq 'Process' -and $Force
        }
    }

    It 'Should not swallow an unrelated Disconnect-AzAccount error' {
        Mock -CommandName Disconnect-AzAccount -ModuleName AzHelpers -MockWith {
            throw [System.InvalidOperationException]::new('The credentials could not be found.')
        }

        Disconnect-M365Dsc -ErrorAction SilentlyContinue -ErrorVariable disconnectError

        $disconnectError[0].Exception.Message | Should -BeLike '*The credentials could not be found.*'
        Should -Invoke -CommandName Clear-AzContext -ModuleName AzHelpers -Times 0 -Exactly
    }
}

Describe 'Add-M365DscIdentityPermission' -Tag Integration {    It 'Should skip the Exchange role groups when Exchange Online is not connected' {
        InModuleScope -ModuleName AzHelpers {
            Mock -CommandName Test-M365DscExchangeOnlineConnection -MockWith { $false }
            Mock -CommandName Get-AzContext -MockWith {
                [pscustomobject]@{ Subscription = [pscustomobject]@{ Id = $null } }
            }
            Mock -CommandName Get-M365DSCCompiledPermissionList2 -MockWith {
                @(
                    [pscustomobject]@{ ApiRoleId = 'roleId1'; ApiAppId = 'apiAppId'; ApiPermissionName = 'Test.Read.All' }
                    [pscustomobject]@{ ApiRoleId = 'roleId2'; ApiAppId = 'apiAppId'; ApiPermissionName = 'Test.Write.All' }
                )
            }
            Mock -CommandName Get-GraphPermission -MockWith {
                [pscustomobject]@{ ApiRoleId = 'roleId3'; ApiAppId = 'apiAppId'; ApiPermissionName = 'AppRoleAssignment.ReadWrite.All' }
            }
            Mock -CommandName Get-ServicePrincipalAppPermissions -MockWith {
                @(
                    [pscustomobject]@{ ApiRoleId = 'roleId1'; ApiAppId = 'apiAppId'; ApiPermissionName = 'Test.Read.All' }
                    [pscustomobject]@{ ApiRoleId = 'roleId2'; ApiAppId = 'apiAppId'; ApiPermissionName = 'Test.Write.All' }
                )
            }
            Mock -CommandName Set-ServicePrincipalAppPermissions
            Mock -CommandName Get-MgDirectoryRole -MockWith { [pscustomobject]@{ DisplayName = 'Global Reader' } }
            Mock -CommandName Get-MgServicePrincipal -MockWith { [pscustomobject]@{ Id = '00000000-0000-0000-0000-000000000002' } }
            Mock -CommandName Get-MgRoleManagementDirectoryRoleDefinition -MockWith { $null }

            $identity = [M365DscIdentity]::new('TestApp', 'objectId', 'appId', '00000000-0000-0000-0000-000000000001', $null, [M365DscIdentityType]::Application)

            # 'Get-RoleGroup' and 'Add-RoleGroupMember' only exist while Exchange Online is connected,
            # so reaching the Exchange role group block would raise a CommandNotFoundException.
            { Add-M365DscIdentityPermission -Identity $identity -AccessType Update } | Should -Not -Throw
        }
    }
}

Describe 'Resolve-M365DscAzureMfaChallenge' -Tag Integration {
    BeforeEach {
        Mock -CommandName Connect-AzAccount -ModuleName AzHelpers
        Mock -CommandName Get-AzContext -ModuleName AzHelpers -MockWith {
            [pscustomobject]@{
                Tenant       = [pscustomobject]@{ Id = 'b246c1af-87ab-41d8-9812-83cd5ff534cb' }
                Subscription = [pscustomobject]@{ Id = '9522bd96-d34f-4910-9667-0517ab5dc595' }
            }
        }
    }

    It 'Should replay the claims challenge of an MFA error' {
        # Verbatim text of the Remove-AzRoleAssignment failure this test guards against.
        $mfaErrorMessage = @'
Resource '00000000-0000-0000-0000-000000000001' was disallowed by Azure: You are receiving this error because you tried to create, update or delete Azure resources without authenticating through MFA.
User accounts must be authenticated through MFA to manage your resources. To resolve this error, go to https://aka.ms/MFAforAzure.  Run the cmdlet below to authenticate interactively; additional
parameters may be added as needed.  Connect-AzAccount -Tenant (Get-AzContext).Tenant.Id -ClaimsChallenge "eyJhY2Nlc3NfdG9rZW4iOnsiYWNycyI6eyJlc3NlbnRpYWwiOnRydWUsInZhbHVlcyI6WyJwMSJdfX19"
'@

        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.Exception]::new($mfaErrorMessage), 'Disallowed', 'PermissionDenied', $null)

        Resolve-M365DscAzureMfaChallenge -ErrorRecord $errorRecord | Should -BeTrue

        Should -Invoke -CommandName Connect-AzAccount -ModuleName AzHelpers -Times 1 -Exactly -ParameterFilter {
            $Tenant -eq 'b246c1af-87ab-41d8-9812-83cd5ff534cb' -and
            $Subscription -eq '9522bd96-d34f-4910-9667-0517ab5dc595' -and
            $ClaimsChallenge -eq 'eyJhY2Nlc3NfdG9rZW4iOnsiYWNycyI6eyJlc3NlbnRpYWwiOnRydWUsInZhbHVlcyI6WyJwMSJdfX19'
        }
    }

    It 'Should not re-authenticate for an unrelated error' {
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.Exception]::new('The role assignment does not exist.'), 'NotFound', 'ObjectNotFound', $null)

        Resolve-M365DscAzureMfaChallenge -ErrorRecord $errorRecord | Should -BeFalse

        Should -Invoke -CommandName Connect-AzAccount -ModuleName AzHelpers -Times 0 -Exactly
    }
}

Describe 'Remove-M365DscIdentityPermission' -Tag Integration {
    It 'Should retry the Owner role removal after replaying the claims challenge' {
        InModuleScope -ModuleName AzHelpers {
            $mfaErrorMessage = 'Resource was disallowed by Azure: You are receiving this error because you tried to create, update or delete Azure resources without authenticating through MFA.  Connect-AzAccount -Tenant (Get-AzContext).Tenant.Id -ClaimsChallenge "eyJhY2Nlc3NfdG9rZW4iOnsiYWNycyI6eyJlc3NlbnRpYWwiOnRydWUsInZhbHVlcyI6WyJwMSJdfX19"'

            Mock -CommandName Get-AzRoleAssignment -MockWith { [pscustomobject]@{ RoleDefinitionName = 'Owner' } }
            Mock -CommandName Connect-AzAccount
            Mock -CommandName Get-AzContext -MockWith {
                [pscustomobject]@{
                    Tenant       = [pscustomobject]@{ Id = 'b246c1af-87ab-41d8-9812-83cd5ff534cb' }
                    Subscription = [pscustomobject]@{ Id = '9522bd96-d34f-4910-9667-0517ab5dc595' }
                }
            }

            $script:removeAttempt = 0
            Mock -CommandName Remove-AzRoleAssignment -MockWith {
                $script:removeAttempt++
                if ($script:removeAttempt -eq 1)
                {
                    throw $mfaErrorMessage
                }
            }

            # The function walks on into the Graph and Exchange Online blocks, which this test does not cover.
            Mock -CommandName Get-MgServicePrincipal -MockWith { throw 'end of the tested path' }

            $identity = [M365DscIdentity]::new('TestApp', 'objectId', 'appId', '00000000-0000-0000-0000-000000000001', 'exchangeId', [M365DscIdentityType]::Application)

            { Remove-M365DscIdentityPermission -Identity $identity -SkipGraphApiPermissions } |
                Should -Throw 'end of the tested path'

            Should -Invoke -CommandName Connect-AzAccount -Times 1 -Exactly -ParameterFilter {
                $ClaimsChallenge -eq 'eyJhY2Nlc3NfdG9rZW4iOnsiYWNycyI6eyJlc3NlbnRpYWwiOnRydWUsInZhbHVlcyI6WyJwMSJdfX19'
            }
            Should -Invoke -CommandName Remove-AzRoleAssignment -Times 2 -Exactly
        }
    }
}

Describe 'Exchange Online entitlement in the lab scripts' -Tag Integration {
    BeforeDiscovery {
        $connectingLabScripts = Get-ChildItem -Path $PSScriptRoot\..\..\lab -Filter *.ps1 | Where-Object {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$null)
            $ast.FindAll({
                    param ($node)
                    $node -is [System.Management.Automation.Language.CommandAst] -and
                    $node.GetCommandName() -eq 'Connect-M365Dsc'
                }, $true)
        } | ForEach-Object { @{ Name = $_.Name; Path = $_.FullName } }
    }

    It "'<Name>' passes the 'HasExchangeOnline' setting on to 'Connect-M365Dsc'" -ForEach $connectingLabScripts {
        # A script that connects without the switch fails on a tenant configured with
        # 'HasExchangeOnline: false', because Connect-M365Dsc then demands the entitlement.
        $content = Get-Content -Path $Path -Raw

        $content | Should -Match 'HasExchangeOnline'
        $content | Should -Match 'SkipExchangeOnline'
    }
}

Describe 'Build agent identity in the lab scripts' -Tag Integration {
    It "'30 Create Agent VMs.ps1' creates the build agent identity as a managed identity" {
        # Without '-OnlyServicePrincipals' the function registers an application of the same
        # display name next to the managed identity created by 'New-AzUserAssignedIdentity'.
        $path = (Resolve-Path -Path "$PSScriptRoot\..\..\lab\30 Create Agent VMs.ps1").Path
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$null)

        $calls = $ast.FindAll({
                param ($node)
                $node -is [System.Management.Automation.Language.CommandAst] -and
                $node.GetCommandName() -eq 'New-M365DscIdentity'
            }, $true)

        $calls | Should -HaveCount 1
        $calls.CommandElements.ParameterName | Should -Contain 'OnlyServicePrincipals'
    }
}

Describe 'Build agent software installation in the lab scripts' -Tag Integration {
    BeforeAll {
        $path = (Resolve-Path -Path "$PSScriptRoot\..\..\lab\31 Agent Setup.ps1").Path
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$null)

        # Covers quoted paths and bare command names alike.
        $script:literals = $ast.FindAll({
                param ($node)
                $node -is [System.Management.Automation.Language.StringConstantExpressionAst]
            }, $true).Value
    }

    It "'31 Agent Setup.ps1' does not download the agent from the retired Azure CDN" {
        # 'vstsagentpackage.azureedge.net' no longer resolves, so the download failed with
        # 'No such host is known'. Chocolatey pulls the agent from download.agent.dev.azure.com.
        $script:literals | Where-Object { $_ -match 'vstsagentpackage\.azureedge\.net' } | Should -BeNullOrEmpty
    }

    It "'31 Agent Setup.ps1' does not call the lab sources script at a hard-coded path" {
        # AutomatedLab writes 'AzureLabSources.ps1' below '$AL_DeployDebugFolder\AL', which expands
        # to '%APPDATA%\DeployDebug\AL' and not to the legacy 'C:\AL'.
        $script:literals | Where-Object { $_ -match 'AzureLabSources\.ps1' } | Should -BeNullOrEmpty
    }
}

Describe 'Remove-M365DscIdentity' -Tag Integration {
    It 'Should not remove an application for an identity that has none' {
        InModuleScope -ModuleName AzHelpers {
            Mock -CommandName Test-M365DscExchangeOnlineConnection -MockWith { $false }
            Mock -CommandName Remove-MgApplication

            # A managed identity resolves to a service principal only, so its 'Id' stays empty.
            $identity = [M365DscIdentity]::new('M365DscLcmM3652DevIdentity', $null, 'appId', 'principalId', $null, [M365DscIdentityType]::ManagedIdentity)

            Remove-M365DscIdentity -Identity $identity

            Should -Invoke -CommandName Remove-MgApplication -Times 0 -Exactly
        }
    }
}
