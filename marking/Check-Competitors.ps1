
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]
    $csvPath = '.\competitors.csv',

    [Parameter(Mandatory = $true)]
    [string]
    $subscriptionId 
)

# Requires POSH SSH module

# CSV Schema
# name,number,resourcegroup,sftpaccount,sftppassword

$competitors = Import-Csv $csvPath
# Debug
# $competitor = $competitors[0]

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
        Write-Output "$($Competitor.Name): B1.1 - 1 - SFTP is enabled"
    }
    else {
        Write-Output "$($Competitor.Name): B1.1 - 0"
    }

    # B1.2
    $SFTPUser = Get-AzStorageLocalUser -resourceGroup $($competitor.resourcegroup) -StorageAccountName $($competitor).sftpaccount -ErrorAction SilentlyContinue | Select-Object Name, HasSshPassword

    if ($SFTPUser.Name -eq 'sftpintegpalkkalaskenta' -and $SFTPUser.HasSshPassword) {
        Write-Output "$($Competitor.Name): B1.2 - 1 - SFTP user sftpintegpalkkalaskenta created and has SSH password"
    }
    else {
        Write-Output "$($Competitor.Name): B1.2 - 0"
    }

    # B1.3
    [pscredential]$SFTPCredential = New-Object System.Management.Automation.PSCredential ("$($competitor.sftpaccount).sftppalkat.sftpintegpalkkalaskenta", $(ConvertTo-SecureString $($competitor.sftppassword) -AsPlainText -Force) )
    $ConnectionEndpoint = "$($competitor.sftpaccount).blob.core.windows.net"
    $SFTPSession = New-SFTPSession -Credential $SFTPCredential -HostName $ConnectionEndpoint -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

    if ($SFTPSession) {
        Write-Output "$($Competitor.Name): B1.3 - 1 - SFTP connection to $ConnectionEndpoint successful"
        $null = Remove-SFTPSession $SFTPSession
    }
    else {
        Write-Output "$($Competitor.Name): B1.3 - 0"
    }

    # B2

    # TODO: CHANGE DNS!
    $DNSName = "kuplakone.c$($competitor.number).tuulet.in"
    $DNSEntry = Resolve-DnsName $DNSName -ErrorAction SilentlyContinue
    $StorageAccountName = $dnsentry[0].namehost.split('.')[0]
    if ($StorageAccountName) {
        # B2.1
        $StorageCtx = New-AzStorageContext -StorageAccountName $StorageAccountName -ErrorAction SilentlyContinue
        $StorageProperties = Get-AzStorageServiceProperty -ServiceType blob -Context $StorageCtx -ErrorAction SilentlyContinue 

        if ($StorageProperties.StaticWebsite.Enabled) {
            Write-Output "$($Competitor.Name): B2.1 - 1 - DNS entry kuplakone.c$($competitor.number).tuulet.in points to storage account $StorageAccountName and has static website enabled."
        }
        else {
            Write-Output "$($Competitor.Name): B2.1 - 0"
        }
        # B2.2
        $Website = Invoke-WebRequest -Uri "http://$($DNSName)" -ErrorAction SilentlyContinue
        if ($Website.Content -like '*<title>Kuplakone Maintenance</title>*') {
            Write-Output "$($Competitor.Name): B2.2 - 1 - Website kuplakone.c$($competitor.number).tuulet.in is reachable and displays maintenance page."
        }
        else {
            Write-Output "$($Competitor.Name): B2.2 - 0"
        }
    }
    else {
    }

}   