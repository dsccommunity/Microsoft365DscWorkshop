# Define organization base url, PAT and API version variables
$orgUrl = 'https://dev.azure.com/randree/Microsoft365DscWorkshop'
$pat = 'jwhj5ydrorm6w2ei7wuruo5wdrtcecpaktyps3cat6paxg4r2umq'
$queryString = 'api-version=5.1'

# Create header with PAT
$token = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($pat)"))
$header = @{authorization = "Basic $token" }

# Get the list of all projects in the organization
$projectsUrl = "$orgUrl/_apis/distributedtask/queues"
$projectsUrl = "$($projectsUrl)?$queryString"
$projects = Invoke-RestMethod -Uri $projectsUrl -Method Get -ContentType 'application/json' -Headers $header
$projects.value | ForEach-Object {
    Write-Host $_.id $_.name
}

$requestBodyAgentPool = @{
    name          = 'Microsot365DscWorkshop'
    autoProvision = $true
    autoUpdate    = $true
    autoSize      = $true
    isHosted      = $false
    poolType      = 'automation'
} | ConvertTo-Json

Invoke-RestMethod -Uri $projectsUrl -Method POST -ContentType 'application/json' -Body $requestBodyAgentPool -Headers $header