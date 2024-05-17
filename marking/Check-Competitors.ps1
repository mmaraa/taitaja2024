
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
# Requires Az module
# Resuires Az.ConnectedMachine module

# CSV Schema
# name,number,resourcegroupname,sftpaccount,sftppassword

$competitors = Import-Csv $csvPath
# Debug
# $competitor = $competitors[0]

# check that we are connected to azure
if (-not (Get-AzContext)) {
    Connect-AzAccount
}

# switch to correct subscription
$null = Set-AzContext -SubscriptionId $subscriptionId

foreach ($competitor in $competitors) {
    # B1 SFTP-palvelu

    # B1.1 SFTP-palvelu enabloitu storage accountista - Storage account vastaa SFTP-palveluun
    $SFTPAccount = $null
    if ($competitor.sftpAccount) {
        $SFTPAccount = Get-AzStorageAccount -resourceGroup $($competitor.resourceGroupName) -StorageAccountName $($competitor).sftpAccount -ErrorAction SilentlyContinue | Select-Object StorageAccountName, ResourceGroupName, EnableSftp
    }
    if ($SFTPAccount.EnableSftp) {
        Write-Host -BackgroundColor Green "$($Competitor.Name): B1.1 - 1 - SFTP is enabled"
    }
    else {
        Write-Host -BackgroundColor Red "$($Competitor.Name): B1.1 - 0"
    }

    # B1.2 Tunnus luotu	- Tunnus löytyy konfiguraatiosta
    $SFTPUser = $null
    if ($competitor.sftpAccount -and $competitor.sftpPassword) {
        $SFTPUser = Get-AzStorageLocalUser -resourceGroup $($competitor.resourceGroupName) -StorageAccountName $($competitor).sftpAccount -ErrorAction SilentlyContinue | Select-Object Name, HasSshPassword
    }

    if ($SFTPUser.Name -eq 'sftpintegpalkkalaskenta' -and $SFTPUser.HasSshPassword) {
        Write-Host -BackgroundColor Green "$($Competitor.Name): B1.2 - 1 - SFTP user sftpintegpalkkalaskenta created and has SSH password"
    }
    else {
        Write-Host -BackgroundColor Red "$($Competitor.Name): B1.2 - 0"
    }

    # B1.3 Tunnus toimii - Tunnuksella pääsee kirjautumaan SFTP-palveluun
    $SFTPSession = $null
    if ($competitor.sftpAccount -and $competitor.sftpPassword) {
        [pscredential]$SFTPCredential = New-Object System.Management.Automation.PSCredential ("$($competitor.sftpAccount).sftppalkat.sftpintegpalkkalaskenta", $(ConvertTo-SecureString $($competitor.sftpPassword) -AsPlainText -Force) )
        $ConnectionEndpoint = "$($competitor.sftpAccount).blob.core.windows.net"
        $SFTPSession = New-SFTPSession -Credential $SFTPCredential -HostName $ConnectionEndpoint -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    }

    if ($SFTPSession) {
        Write-Host -BackgroundColor Green "$($Competitor.Name): B1.3 - 1 - SFTP connection to $ConnectionEndpoint successful"
        $null = Remove-SFTPSession $SFTPSession
    }
    else {
        Write-Host -BackgroundColor Red "$($Competitor.Name): B1.3 - 0"
    }

    # B2 Web-sivu

    $DNSName = "kuplakone.k$($competitor.number).kupla.eu"
    $DNSEntry = Resolve-DnsName $DNSName -ErrorAction SilentlyContinue
    if ($DNSEntry) {
        $StorageAccountName = $dnsentry[0].namehost.split('.')[0]
        if ($StorageAccountName) {
            # B2.1 Staattinen web-sivu otettu käyttöön - Storage accountista enabloitu static web page

            $StorageCtx = New-AzStorageContext -StorageAccountName $StorageAccountName -ErrorAction SilentlyContinue
            $StorageProperties = Get-AzStorageServiceProperty -ServiceType blob -Context $StorageCtx -ErrorAction SilentlyContinue 

            if ($StorageProperties.StaticWebsite.Enabled) {
                Write-Host -BackgroundColor Green "$($Competitor.Name): B2.1 - 1 - DNS entry $DNSName points to storage account $StorageAccountName and has static website enabled."
            }
            else {
                Write-Host -BackgroundColor Red "$($Competitor.Name): B2.1 - 0"
            }
            # B2.2 Web-sivu aukeaa selaimella - Annettu index.html-sivu aukeaa

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
    }
    else {
        Write-Host -BackgroundColor Red "$($Competitor.Name): B2.1 - 0"
        Write-Host -BackgroundColor Red "$($Competitor.Name): B2.2 - 0"
    }

    # B3 Automatisoinnin modernisointi

    # B3.1 Kone yhdistetty Azureen - Arc-objekti löytyy connected-tilassa

    $ArcMachine = Get-AzConnectedMachine -ResourceGroupName $($competitor.resourceGroupName) -ErrorAction SilentlyContinue

    if ($ArcMachine.Status -eq 'Connected') {
        Write-Host -BackgroundColor Green "$($Competitor.Name): B3.1 - 1 - Azure Arc machine $($ArcMachine.Name) is connected"
    }
    else {
        Write-Host -BackgroundColor Red "$($Competitor.Name): B3.1 - 0"
    }

    # B3.2 Scheduled task siirretty pilveen	- Sama koodi löytyy automation runbookista
    # B3.3 Ajastus konfiguroitu automaatioon kuten palvelimella	- Schedule löytyy samalla aikataulutuksella
    $AutomationAccount = Get-AzAutomationAccount -ResourceGroupName $($competitor.resourceGroupName) -ErrorAction SilentlyContinue
    $ContentMatch = $false
    $ScheduleMatch = $false

    if ($AutomationAccount) {
        $AutomationRunbook = Get-AzAutomationRunbook -ResourceGroupName $($competitor.resourceGroupName) -AutomationAccount $AutomationAccount.AutomationAccountName -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike 'AzureAutomationTutorialWithIdentity*' -and $_.State -like 'Published' } | Select-Object Name, State

        if ($AutomationRunbook) {
            foreach ($Runbook in $AutomationRunbook) {
                $null = New-Item -Path "\work\marking\$($competitor.Name)" -ItemType Directory -Force -ErrorAction SilentlyContinue
                $null = Export-AzAutomationRunbook -ResourceGroupName $($competitor.resourceGroupName) -AutomationAccountName $AutomationAccount.AutomationAccountName -Name $Runbook.Name -Slot 'Published' -OutputFolder "\work\marking\$($competitor.Name)\" -Force -ErrorAction SilentlyContinue
                # Check if file contains string
                if ($(Get-Content -Path "\work\marking\$($competitor.name)\$($Runbook.Name).ps1") -like 'Remove-Item -Path c:\temp\* -Force') {
                    $ContentMatch = $true
                    $Schedule = Get-AzAutomationScheduledRunbook -ResourceGroupName $($competitor.resourceGroupName) -AutomationAccountName $AutomationAccount.AutomationAccountName -RunbookName $Runbook.Name -ErrorAction SilentlyContinue
                    $ScheduleDetails = Get-AzAutomationSchedule -ResourceGroupName $($competitor.resourceGroupName) -AutomationAccountName $AutomationAccount.AutomationAccountName -Name $Schedule.ScheduleName -ErrorAction SilentlyContinue 
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
    else {
        Write-Host -BackgroundColor Red "$($Competitor.Name): B3.2 - 0"
        Write-Host -BackgroundColor Red "$($Competitor.Name): B3.3 - 0"
    }


    # TODO B3.4 Automaatio toimii - Automaatio tekee pyydetyt asiat palvelimella 

    # B4 Azure valvonta

    # B4.1 Automaation ongelmahälytys toimii - Hälytys tulee sähköpostiin
    # Needs to be planned, how error can be triggered
    # Manual check in email
    $LogMonitorRules = Get-AzResource -ResourceGroupName $competitor.resourceGroupName -ResourceType microsoft.insights/scheduledqueryrules
    if ($LogMonitorRules) {
        Write-Host -BackgroundColor Yellow "$($Competitor.Name): B4.1 -   - MONITORING RULES PRESENT - CHECK EMAIL!"
    }
    else {
        Write-Host -BackgroundColor Red "$($Competitor.Name): B4.1 - 0"
    }

    # B4.2 VM Insights otettu käyttöön pyydetysti VM Insights perf ja dependency arcatulla koneella
    $ArcExtensions = $null
    if ($ArcMachine) {
        $ArcExtensions = Get-AzConnectedMachineExtension -MachineName $ArcMachine.Name -ResourceGroupName $($competitor.resourceGroupName) -ErrorAction SilentlyContinue
    }
    if ($ArcExtensions.Name -contains 'AzureMonitorWindowsAgent' -and $ArcExtensions.Name -contains 'DependencyAgentWindows') {
        Write-Host -BackgroundColor Yellow "$($Competitor.Name): B4.2 -   - Dependency Agent extension is installed on Azure Arc machine $($ArcMachine.Name). CHECK FUNCTIONALITY!"
    }
    else {
        Write-Host -BackgroundColor Red "$($Competitor.Name): B4.2 - 0"
    }

    # B5 Moderni hallinta
    # B5.1 Windows Admin Center asennettu ja toimii Villellä - Ville pääsee kirjautumaan sisään WAC:iin
    if ($ArcExtensions.Name -contains 'AdminCenter') {
        Write-Host -BackgroundColor Yellow "$($Competitor.Name): B5.1 -   - Windows Admin Center extension is installed on Azure Arc machine $($ArcMachine.Name). CHECK FUNCTIONALITY!"
    }
    else {
        Write-Host -BackgroundColor Red "$($Competitor.Name): B5.1 - 0"
    }
}   