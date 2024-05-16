
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]
    $csvPath = ".\competitors.csv",

    [Parameter(Mandatory = $true)]
    [string]
    $subscriptionId 
)

# Requires POSH SSH module


$competitors = Import-Csv $csvPath

# check that we are connected to azure
if (-not (Get-AzContext)) {
    Connect-AzAccount
}

# switch to correct subscription
$context = Set-AzContext -SubscriptionId $subscriptionId

foreach ($competitor in $competitors) {
    # B1.1
    $SFTPAccount = Get-AzStorageAccount -resourceGroup $($competitor.resourcegroup) -StorageAccountName $($competitor).sftpaccount -ErrorAction SilentlyContinue | Select-Object StorageAccountName, ResourceGroupName, EnableSftp

    if ($SFTPAccount.EnableSftp) {
        Write-Output "$($Competitor.Name): B1.1 - SFTP is enabled"
    } else {

    }

    # B1.2
    $SFTPUser = Get-AzStorageLocalUser -resourceGroup $($competitor.resourcegroup) -StorageAccountName $($competitor).sftpaccount -ErrorAction SilentlyContinue | Select-Object Name, HasSshPassword

    if ($SFTPUser.Name -eq "sftpintegpalkkalaskenta" -and $SFTPUser.HasSshPassword) {
        Write-Output "$($Competitor.Name): B1.2 - SFTP user sftpintegpalkkalaskenta created and has SSH password"
    } else {

    }

    # B1.3
    [pscredential]$SFTPCredential = New-Object System.Management.Automation.PSCredential ("$($competitor.sftpaccount).sftppalkat.sftpintegpalkkalaskenta", $(ConvertTo-SecureString $($competitor.sftppassword) -AsPlainText -Force) )
    $ConnectionEndpoint = "$($competitor.sftpaccount).blob.core.windows.net"
    $SFTPSession = New-SFTPSession -Credential $SFTPCredential -HostName $ConnectionEndpoint -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

    if ($SFTPSession) {
        Write-Output "$($Competitor.Name): B1.3 - SFTP connection to $ConnectionEndpoint successful"
        $null = Remove-SFTPSession $SFTPSession
    } else {

    }

    

}   