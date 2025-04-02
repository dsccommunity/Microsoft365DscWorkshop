# Entra ID Group Management Scripts

This folder contains PowerShell scripts for creating and managing Entra ID (formerly Azure AD) groups using Microsoft Graph API.

## Files

- **Create-EntraIDGroup.ps1**: Core script that creates Entra ID groups using Microsoft Graph API
- **Example-CreateGroups.ps1**: Example script demonstrating the usage of the core script

## Prerequisites

1. PowerShell 5.1 or later
2. Microsoft Graph PowerShell modules:
   - Microsoft.Graph.Authentication
   - Microsoft.Graph.Identity.DirectoryManagement

   ```powershell
   Install-Module -Name Microsoft.Graph.Authentication, Microsoft.Graph.Identity.DirectoryManagement -Scope CurrentUser
   ```

3. An app registration in Entra ID with appropriate permissions:
   - Group.Create
   - Group.ReadWrite.All
   - Directory.ReadWrite.All
   - User.ReadWrite.All (for adding members/owners)

## Setting Up App Registration

1. Sign in to the [Azure Portal](https://portal.azure.com)
2. Navigate to **Microsoft Entra ID** > **App registrations** > **New registration**
3. Provide a name for your app (e.g., "Group Management App")
4. Select the appropriate supported account types 
5. Click **Register**
6. Note the **Application (client) ID** and **Directory (tenant) ID**
7. Navigate to **API permissions** > **Add a permission** > **Microsoft Graph** > **Application permissions**
8. Add the following permissions:
   - Group.Create
   - Group.ReadWrite.All
   - Directory.ReadWrite.All
   - User.ReadWrite.All
9. Click **Grant admin consent**
10. Create a client secret:
    - Navigate to **Certificates & secrets** > **New client secret**
    - Provide a description and select an expiry period
    - Click **Add**
    - Copy the generated secret value immediately (you won't be able to see it again)

## Usage

### Basic Usage

```powershell
.\Create-EntraIDGroup.ps1 `
    -TenantId "your-tenant-id" `
    -ClientId "your-client-id" `
    -ClientSecret "your-client-secret" `
    -DisplayName "My New Group" `
    -Description "Description of the group" `
    -MailNickname "MyNewGroup"
```

### Creating Different Group Types

#### Security Group (Default)

```powershell
.\Create-EntraIDGroup.ps1 `
    -TenantId "your-tenant-id" `
    -ClientId "your-client-id" `
    -ClientSecret "your-client-secret" `
    -DisplayName "Finance Security Group" `
    -Description "Security group for Finance department" `
    -MailNickname "FinanceSecurity"
```

#### Microsoft 365 Group

```powershell
.\Create-EntraIDGroup.ps1 `
    -TenantId "your-tenant-id" `
    -ClientId "your-client-id" `
    -ClientSecret "your-client-secret" `
    -DisplayName "Marketing Team" `
    -Description "Microsoft 365 group for Marketing department" `
    -MailNickname "MarketingTeam" `
    -GroupType "Microsoft365" `
    -Visibility "Public"
```

#### Role-Assignable Security Group

```powershell
.\Create-EntraIDGroup.ps1 `
    -TenantId "your-tenant-id" `
    -ClientId "your-client-id" `
    -ClientSecret "your-client-secret" `
    -DisplayName "Global Admin Group" `
    -Description "Security group for Global Administrators" `
    -MailNickname "GlobalAdmins" `
    -GroupType "Security" `
    -IsAssignableToRole $true
```

#### Mail-Enabled Security Group

```powershell
.\Create-EntraIDGroup.ps1 `
    -TenantId "your-tenant-id" `
    -ClientId "your-client-id" `
    -ClientSecret "your-client-secret" `
    -DisplayName "IT Support Team" `
    -Description "Mail-enabled security group for IT Support team" `
    -MailNickname "ITSupport" `
    -GroupType "MailEnabledSecurity"
```

### Adding Members and Owners

```powershell
.\Create-EntraIDGroup.ps1 `
    -TenantId "your-tenant-id" `
    -ClientId "your-client-id" `
    -ClientSecret "your-client-secret" `
    -DisplayName "Project X Team" `
    -Description "Team working on Project X" `
    -MailNickname "ProjectXTeam" `
    -GroupType "Microsoft365" `
    -MemberUserPrincipalNames @("user1@contoso.com", "user2@contoso.com") `
    -OwnerUserPrincipalNames @("admin@contoso.com")
```

## Example Script

The `Example-CreateGroups.ps1` script demonstrates how to create different types of groups. Update the script with your tenant ID, client ID, and client secret before running it.

## Troubleshooting

### Common Issues

1. **Module Not Found**: 
   ```
   Required module 'Microsoft.Graph.Authentication' is not installed
   ```
   **Solution**: Run `Install-Module -Name Microsoft.Graph.Authentication -Scope CurrentUser`

2. **Authentication Failed**:
   ```
   Failed to connect to Microsoft Graph API
   ```
   **Possible Solutions**:
   - Verify your TenantId, ClientId, and ClientSecret
   - Ensure the app registration has the required permissions
   - Check that admin consent was granted for the permissions

3. **Insufficient Permissions**:
   ```
   Error creating group: Insufficient privileges to complete the operation
   ```
   **Solution**: Make sure your app has been granted the required permissions listed in the Prerequisites section

4. **Invalid User Principal Name**:
   ```
   User 'user@contoso.com' not found and could not be added as member
   ```
   **Solution**: Ensure the user exists in your tenant and the UPN is correct
