# Graph API Cmdlets

For using the Graph API, we have to install the respective module first.

```powershell
Install-Module -Name Microsoft.Graph.Groups -Force
```

Let's see what groups are already in the tenant. First, we need to connect to the tenant. Please take the login data from the yaml-file `SummitTestUser1.yaml`. To connect with an application and application secrets, we need to create a `pscredential` object first. The username is the `AppId`, the password the decrypted `EncSecret`.

```powershell
$cred = [pscredential]::new('f8c36e29-ae85-450c-ac9c-bc25e527367b', ('ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMN' | ConvertTo-SecureString -AsPlainText -Force))
```

Then we use this credential object to connect to the tenant.

```powershell
Connect-MgGraph -ClientSecretCredential $cred -TenantId a1627b4f-281e-4f8b-bf13-bddc0eb6857e
```

> :information_source: Why are we not using the user account but the application to connect to the Graph API? Usually enforced MFA, IP restrictions, or device compliance policies will break automation. Service principals bypass MFA while maintaining security. Access can be restricted via certificates, IP whitelisting, or managed identities instead. The key benefit is reliable automation without interruptions from user security policies.

### [Get-MgGroup](https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.groups/get-mggroup?view=graph-powershell-1.0)

After connecting to the tenant we can interact with it. By default `Get-MgGroup` returns all groups. You can filter like this:

```powershell
Get-MgGroup -Search '"DisplayName:Contoso"' -ConsistencyLevel eventual
```

> :information_source: The cmdlet `Get-MgContext` tells you to which tenant you are currently connected. It also tells you which permissions you have. Reading users with `Get-MgUser` should not be possible and will throw 'Insufficient privileges to complete the operation' as we don't have the necessary scopes in the access token.

### [New-MgGroup](https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.groups/new-mggroup?view=graph-powershell-1.0)

Now we create a new group. Please run the command. You may name the group as you like.

```powershell
New-MgGroup -DisplayName 'Test Group' -MailEnabled:$false -MailNickName 'testgroup' -SecurityEnabled
```

> :information_source: You don't have to be very creative when choosing the group name, as unlike Active Directory you can have several groups with the same name (but a different object ID).

Let's see how many test groups we have in the tenant. For that we have the `Filter` parameter a [filter query language](https://learn.microsoft.com/en-us/graph/filter-query-parameter?tabs=http). Getting all test groups (`Test Group *`) works like this:

```powershell
Get-MgGroup -Filter "startswith(DisplayName,'Test Group')"
```

```text
DisplayName  Id                                   MailNickname Description  GroupTypes
-----------  --                                   ------------ -----------  ----------
Test Group 1 0de9d83f-6256-4065-9a8f-00160a3b45c2 TestGroup1   Test Group 1 {}
Test Group 1 568fd380-5dd4-48ed-88ae-d14109974d1c testgroup1                {}
Test Group 1 cc7b4e34-750b-4cd7-ae1f-d6fab46d2e14 testgroup1                {}
Test Group 1 dc67dc62-1d83-4c67-a363-bf8522231e51 testgroup1                {}
```

---

This was just to see how to interact with Entra ID via the Graph API. In the next task [Desired State Configuration Basics](./30%20DSC%20Basics.md) we will move on to DSC.
