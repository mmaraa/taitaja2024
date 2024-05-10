# Input parameters 
param (
    [Parameter(Mandatory = $true)]
    [string]$csvPath,
    [Parameter(Mandatory = $false)]
    [string]$deploymentLocation = 'swedencentral',
    [Parameter(Mandatory = $true)]
    [string]$competitionName,
    [Parameter(Mandatory = $true)]
    [string]$rootDnsZoneId,
    [Parameter(Mandatory = $true)]
    [string]$targetSubscriptionId
)

# Connect to Azure for deployment
try {
    Connect-AzAccount
    Set-AzContext -Subscription $targetSubscriptionId
}
catch {
    throw 'Login failed.'
}

# Get CSV Data for all the competitor user accounts
$competitorUserAccounts = Import-Csv -Path $csvPath -Encoding utf8

# Start creating the infrastructure for each competitor

try {
    foreach($competitor in $competitorUserAccounts) {
        try {
            New-AzDeployment -Location $deploymentLocation -TemplateFile ".\competitor.bicep" -UserPrincipalName $competitor.UserPrincipalName -userObjectId $competitor.ObjectId -competitionName $competitionName -rootDnsZoneId $rootDnsZoneId -deplLocation $deploymentLocation
        }
        catch {
            throw "Could not create infrastructure for competitor $($competitor.UserPrincipalName). $($_.Exception)"
        }
    }
}
catch {
    throw "Failed to create infrastructure for the competitors. $($_.Exception)"
}