
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
Set-AzContext -SubscriptionId $subscriptionId

foreach ($competitor in $competitors) {
    # B1.1
    $SFTPAccount = Get-AzStorageAccount -resourceGroup $($competitor.resourcegroup) -StorageAccountName $($competitor).sftpaccount -ErrorAction SilentlyContinue | Select-Object StorageAccountName, ResourceGroupName, EnableSftp

    if ($SFTPAccount.EnableSftp) {
        Write-Host -BackgroundColor Green "$($Competitor.Name): B1.1 - 1 - SFTP is enabled"
    }
    else {
        Write-Host -BackgroundColor Red "$($Competitor.Name): B1.1 - 0"
    }

    # B1.2
    $SFTPUser = Get-AzStorageLocalUser -resourceGroup $($competitor.resourcegroup) -StorageAccountName $($competitor).sftpaccount -ErrorAction SilentlyContinue | Select-Object Name, HasSshPassword

    if ($SFTPUser.Name -eq 'sftpintegpalkkalaskenta' -and $SFTPUser.HasSshPassword) {
        Write-Host -BackgroundColor Green "$($Competitor.Name): B1.2 - 1 - SFTP user sftpintegpalkkalaskenta created and has SSH password"
    }
    else {
        Write-Host -BackgroundColor Red "$($Competitor.Name): B1.2 - 0"
    }

    # B1.3
    [pscredential]$SFTPCredential = New-Object System.Management.Automation.PSCredential ("$($competitor.sftpaccount).sftppalkat.sftpintegpalkkalaskenta", $(ConvertTo-SecureString $($competitor.sftppassword) -AsPlainText -Force) )
    $ConnectionEndpoint = "$($competitor.sftpaccount).blob.core.windows.net"
    $SFTPSession = New-SFTPSession -Credential $SFTPCredential -HostName $ConnectionEndpoint -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

    if ($SFTPSession) {
        Write-Host -BackgroundColor Green "$($Competitor.Name): B1.3 - 1 - SFTP connection to $ConnectionEndpoint successful"
        $null = Remove-SFTPSession $SFTPSession
    }
    else {
        Write-Host -BackgroundColor Red "$($Competitor.Name): B1.3 - 0"
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
            Write-Host -BackgroundColor Green "$($Competitor.Name): B2.1 - 1 - DNS entry kuplakone.c$($competitor.number).tuulet.in points to storage account $StorageAccountName and has static website enabled."
        }
        else {
            Write-Host -BackgroundColor Red "$($Competitor.Name): B2.1 - 0"
        }
        # B2.2
        $Website = Invoke-WebRequest -Uri "http://$($DNSName)" -ErrorAction SilentlyContinue
        if ($Website.Content -like '*<title>Kuplakone Maintenance</title>*') {
            Write-Host -BackgroundColor Green "$($Competitor.Name): B2.2 - 1 - Website kuplakone.c$($competitor.number).tuulet.in is reachable and displays maintenance page."
        }
        else {
            Write-Host -BackgroundColor Red "$($Competitor.Name): B2.2 - 0"
        }
    }
    else {
        Write-Host -BackgroundColor Red "$($Competitor.Name): B2.1 - 0"
        Write-Host -BackgroundColor Red "$($Competitor.Name): B2.2 - 0"
    }

    # B3

    # B3.1
    $ArcMachine = Get-AzConnectedMachine -ResourceGroupName $($competitor.resourcegroup) -ErrorAction SilentlyContinue | Select-Object ResourceGroupName, Name, Status

    if ($ArcMachine.Status -eq 'Connected') {
        Write-Host -BackgroundColor Green "$($Competitor.Name): B3.1 - 1 - Azure Arc machine $($ArcMachine.Name) is connected"
    }
    else {
        Write-Host -BackgroundColor Red "$($Competitor.Name): B3.1 - 0"
    }

    # B3.2
    $AutomationAccount = Get-AzAutomationAccount -ResourceGroupName $($competitor.resourcegroup) -ErrorAction SilentlyContinue
    $ContentMatch = $false
    $ScheduleMatch = $false

    if ($AutomationAccount) {
        $AutomationRunbook = Get-AzAutomationRunbook -ResourceGroupName $($competitor.resourcegroup) -AutomationAccount $AutomationAccount.AutomationAccountName -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike 'AzureAutomationTutorialWithIdentity*' -and $_.State -like 'Published' } | Select-Object Name, State

        if ($AutomationRunbook) {
            foreach ($Runbook in $AutomationRunbook) {
                $null = New-Item -Path "\work\marking\$($competitor.Name)" -ItemType Directory -Force -ErrorAction SilentlyContinue
                $null = Export-AzAutomationRunbook -ResourceGroupName $($competitor.resourcegroup) -AutomationAccountName $AutomationAccount.AutomationAccountName -Name $Runbook.Name -Slot 'Published' -OutputFolder "\work\marking\$($competitor.Name)\" -Force -ErrorAction SilentlyContinue
                # Check if file contains string
                if ($(Get-Content -Path "\work\marking\$($competitor.name)\$($Runbook.Name).ps1") -like 'Remove-Item -Path c:\temp\* -Force') {
                    $ContentMatch = $true
                    $Schedule = Get-AzAutomationScheduledRunbook -ResourceGroupName $($competitor.resourcegroup) -AutomationAccountName $AutomationAccount.AutomationAccountName -RunbookName $Runbook.Name -ErrorAction SilentlyContinue
                    $ScheduleDetails = Get-AzAutomationSchedule -ResourceGroupName $($competitor.resourcegroup) -AutomationAccountName $AutomationAccount.AutomationAccountName -Name $Schedule.ScheduleName -ErrorAction SilentlyContinue 
                    if (($ScheduleDetails.WeeklyScheduleOptions.DaysOfWeek -contains 'Monday') -and ($ScheduleDetails.Frequency -eq 'week') -and ($ScheduleDetails.NextRun.TimeOfDay -eq '04:00:00')) {
                        $ScheduleMatch = $true
                    }
                    else {
                    }
                }
            }
            if ($ContentMatch) {
                Write-Host -BackgroundColor Green "$($Competitor.Name): B3.2 - 1 - Runbook $($Runbook.Name) contains Remove-Item -Path c:\temp\* -Force"
            }
            else {
                Write-Host -BackgroundColor Red "$($Competitor.Name): B3.2 - 0"
            }
            if ($ScheduleMatch) {
                Write-Host -BackgroundColor Green "$($Competitor.Name): B3.3 - 1 - Runbook $($Runbook.Name) is scheduled to run on Mondays at 04:00"
            }
            else {
                Write-Host -BackgroundColor Red "$($Competitor.Name): B3.3 - 0"
            }
        }
        else {
            Write-Host -BackgroundColor Red "$($Competitor.Name): B3.2 - 0"
            Write-Host -BackgroundColor Red "$($Competitor.Name): B3.3 - 0"
        }
    }

}   