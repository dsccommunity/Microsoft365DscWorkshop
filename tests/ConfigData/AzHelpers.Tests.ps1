BeforeAll {
    $requiredModulesPath = (Resolve-Path -Path $PSScriptRoot\..\..\output\RequiredModules).Path
    if ($env:PSModulePath -notlike "*$requiredModulesPath*")
    {
        $env:PSModulePath = $env:PSModulePath + [IO.Path]::PathSeparator + $requiredModulesPath
    }

    Import-Module -Name Az.Accounts -RequiredVersion 5.3.2 -Force
    Import-Module -Name Microsoft.Graph.Authentication -RequiredVersion 2.35.1 -Force
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
