# Define organization base url, PAT and API version variables
$orgUrl = 'https://dev.azure.com/randree'
$pat = 'paaixlemjajrgrcrvms7ad73qrwfet2an2hwfdvzudo7ulbuqd6a'
$queryString = 'api-version=5.1'

# Create header with PAT
$token = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($pat)"))
$header = @{authorization = "Basic $token" }

# Get the list of all projects in the organization
$projectsUrl = "$orgUrl/_apis/projects?$queryString"
$projects = Invoke-RestMethod -Uri $projectsUrl -Method Get -ContentType 'application/json' -Headers $header
$projects.value | ForEach-Object {
    Write-Host $_.id $_.name
}
return
# Create new project named OTGRESTDemo
$projectName = 'OTGRESTDemo'
$createProjectURL = "$orgUrl/_apis/projects?$queryString"
$projectJSON = @{name = "$($projectName)"
    description       = 'OTG Azure DevOps REST API Demo'
    capabilities      = @{
        versioncontrol  = @{
            sourceControlType = 'Git'
        }
        processTemplate = @{
            # Basic Project
            templateTypeId = 'b8a3a935-7e91-48b8-a94c-606d37c3e9f2'
                    
        }
    }
} | ConvertTo-Json
$response = Invoke-RestMethod -Uri $createProjectURL -Method Post -ContentType 'application/json' -Headers $header -Body ($projectJSON )

# Wait for 5 seconds
Start-Sleep -s 5

# Get Operation Status for Create Project
$operationStatusUrl = "$orgUrl/_apis/operations/$($response.id)?$queryString"
$response = Invoke-RestMethod -Uri $operationStatusUrl -Method Get -ContentType 'application/json' -Headers $header
Write-Host "Create Project Status: $response.status"

# Get detailed project information
$projectDetailsUrl = "$orgUrl/_apis/projects/$($projectName)?includeCapabilities=True&$queryString"
$projectDetails = Invoke-RestMethod -Uri $projectDetailsURL -Method Get -ContentType 'application/json' -Headers $header
$projectId = $projectDetails.id
Write-Host ($projectDetails | ConvertTo-Json | ConvertFrom-Json)

# Update Project description of OTGRESTDemo project
$jsonData = @{description = 'This is the updated project description for OTGRESTDemo'
} | ConvertTo-Json
$projectUpdateURL = "$orgUrl/_apis/projects/$($projectId)?$queryString"
$response = Invoke-RestMethod -Uri $projectUpdateURL -Method PATCH -ContentType 'application/json' -Headers $header -Body ($jsonData)
return
# Wait for 5 seconds
Start-Sleep -s 5

# Get Update Operation Status
$operationStatusUrl = "$orgUrl/_apis/operations/$($response.id)?$queryString"
$response = Invoke-RestMethod -Uri $operationStatusUrl -Method Get -ContentType 'application/json' -Headers $header
Write-Host 'Update Project Status:' $response.status

$confirmation = Read-Host "Are you sure you want to delete the project $($projectName) (y/n)"
if ($confirmation.ToLower() -eq 'y')
{
    # Delete a project
    $deleteURL = "$orgUrl/_apis/projects/$($projectId)?$queryString"
    $response = Invoke-RestMethod -Uri $deleteURL -Method Delete -ContentType 'application/json' -Headers $header
    # Wait for 5 seconds
    Start-Sleep -s 5
    # Get Update Operation Status
    $operationStatusUrl = "$orgUrl/_apis/operations/$($response.id)?$queryString"
    $response = Invoke-RestMethod -Uri $operationStatusUrl -Method Get -ContentType 'application/json' -Headers $header
    Write-Host 'Delete Project Status:' $response.status
}
else
{
    Write-Host 'Project not deleted. Scipt completed.'
}