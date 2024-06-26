<#
.SYNOPSIS
This script checks various criteria for competitors in a Taitaja competition.

.DESCRIPTION
The script checks different aspects of competitors' configurations, such as SFTP service, web page, automation, and Azure monitoring.

.PARAMETER csvPath
The path to the CSV file containing competitor information. Default value is '.\competitors.csv'.

.PARAMETER subscriptionId
The subscription ID to use for the checks.

.NOTES
Author: Mika Vilpo
Date: 2024-05-20

.EXAMPLE
.\Check-Competitors.ps1 -csvPath '.\competitors.csv' -subscriptionId '00000000-0000-0000-0000-000000000000'
#>

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

# Debugging
# $competitor = $competitors[1]

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
        $SFTPAccount = Get-AzStorageAccount -resourceGroup $($competitor.resourceGroupName) -StorageAccountName $($competitor.sftpAccount) -ErrorAction SilentlyContinue | Select-Object StorageAccountName, ResourceGroupName, EnableSftp
    }
    if ($SFTPAccount.EnableSftp) {
        Write-Host -BackgroundColor Green "$($Competitor.Name): B1.1 - 1 - SFTP is enabled"

        # B1.2 Tunnus luotu	- Tunnus löytyy konfiguraatiosta
        $SFTPUser = $null
        if ($competitor.sftpAccount) {
            $SFTPUser = Get-AzStorageLocalUser -resourceGroup $($competitor.resourceGroupName) -StorageAccountName $($competitor).sftpAccount -ErrorAction SilentlyContinue | Select-Object Name, HasSshPassword
        }

        if ($SFTPUser.Name -eq 'sftpintegpalkkalaskenta' -and $SFTPUser.HasSshPassword) {
            Write-Host -BackgroundColor Green "$($Competitor.Name): B1.2 - 1 - SFTP user sftpintegpalkkalaskenta created and has SSH password"

            # B1.3 Tunnus toimii - Tunnuksella pääsee kirjautumaan SFTP-palveluun
            $SFTPSession = $null
            $ConnectionEndpoint = $null
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
                Write-Host -BackgroundColor Red "$($Competitor.Name): B1.3 - 0 - SFTP connection to $ConnectionEndpoint failed"
            }
        }
        else {
            Write-Host -BackgroundColor Red "$($Competitor.Name): B1.2 - 0 - SFTP user sftpintegpalkkalaskenta not found or does not have SSH password"
            Write-Host -BackgroundColor Red "$($Competitor.Name): B1.3 - 0 - SFTP user sftpintegpalkkalaskenta not found or does not have SSH password"
        }
    }
    else {
        Write-Host -BackgroundColor Red "$($Competitor.Name): B1.1 - 0 - SFTP is not enabled"
        Write-Host -BackgroundColor Red "$($Competitor.Name): B1.2 - 0 - SFTP is not enabled"
        Write-Host -BackgroundColor Red "$($Competitor.Name): B1.3 - 0 - SFTP is not enabled"
    }

    # B2 Web-sivu

    $DNSName = "kuplakone.k$($competitor.number).kupla.eu"
    $DNSEntry = Resolve-DnsName $DNSName -ErrorAction SilentlyContinue | Where-Object { $_.Type -eq 'CNAME' }
    if ($DNSEntry) {
        $StorageAccountName = $dnsentry[0].namehost.split('.')[0]
        $StorageAccount = Get-AzStorageAccount -ResourceGroupName $($competitor.resourceGroupName) -Name $StorageAccountName -ErrorAction SilentlyContinue  

        if ($StorageAccount) {
            # B2.1 Staattinen web-sivu otettu käyttöön - Storage accountista enabloitu static web page

            $StorageProperties = Get-AzStorageServiceProperty -ServiceType blob -Context $StorageAccount.Context -ErrorAction SilentlyContinue 

            if ($StorageProperties.StaticWebsite.Enabled) {
                Write-Host -BackgroundColor Green "$($Competitor.Name): B2.1 - 1 - DNS entry $DNSName points to storage account $StorageAccountName and has static website enabled."
            }
            else {
                Write-Host -BackgroundColor Red "$($Competitor.Name): B2.1 - 0 - DNS entry $DNSName points to storage account $StorageAccountName but static website is not enabled."
            }
            # B2.2 Web-sivu aukeaa selaimella - Annettu index.html-sivu aukeaa

            $Website = $null
            $Website = Invoke-WebRequest -Uri "http://$($DNSName)" -ErrorAction SilentlyContinue
            if ($Website.Content -like '*<title>Kuplakone Maintenance</title>*') {
                Write-Host -BackgroundColor Green "$($Competitor.Name): B2.2 - 1 - Website $DNSName is reachable and displays maintenance page."
            }
            else {
                Write-Host -BackgroundColor Red "$($Competitor.Name): B2.2 - 0 - Website $DNSName is not reachable or does not display maintenance page."
            }
        }
        else {
            Write-Host -BackgroundColor Red "$($Competitor.Name): B2.1 - 0 - DNS entry $DNSName does not point to a storage account"
            Write-Host -BackgroundColor Red "$($Competitor.Name): B2.2 - 0 - DNS entry $DNSName does not point to a storage account"
        }
    }
    else {
        Write-Host -BackgroundColor Red "$($Competitor.Name): B2.1 - 0 - DNS entry $DNSName not found"
        Write-Host -BackgroundColor Red "$($Competitor.Name): B2.2 - 0 - DNS entry $DNSName not found"
    }

    # B3 Automatisoinnin modernisointi

    # B3.1 Kone yhdistetty Azureen - Arc-objekti löytyy connected-tilassa

    $ArcMachine = Get-AzConnectedMachine -ResourceGroupName $($competitor.resourceGroupName) -ErrorAction SilentlyContinue

    if ($ArcMachine.Status -eq 'Connected') {
        Write-Host -BackgroundColor Green "$($Competitor.Name): B3.1 - 1 - Azure Arc machine $($ArcMachine.Name) is connected"
    }
    else {
        Write-Host -BackgroundColor Red "$($Competitor.Name): B3.1 - 0 - Azure Arc machine not connected"
    }

    # B3.2 Scheduled task siirretty pilveen	- Sama koodi löytyy automation runbookista
    # B3.3 Ajastus konfiguroitu automaatioon kuten palvelimella	- Schedule löytyy samalla aikataulutuksella
    $AutomationAccount = Get-AzAutomationAccount -ResourceGroupName $($competitor.resourceGroupName) -ErrorAction SilentlyContinue
    $ContentMatch = $false
    $ScheduleMatch = $false

        if ($AutomationAccount) {
            $AutomationRunbook = Get-AzAutomationRunbook -ResourceGroupName $($competitor.resourceGroupName) -AutomationAccount $AutomationAccount.AutomationAccountName -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike 'AzureAutomationTutorialWithIdentity*' } | Select-Object Name, State

            if ($AutomationRunbook) {
                foreach ($Runbook in $AutomationRunbook) {
                    $null = New-Item -Path "\work\marking\$($competitor.Name)" -ItemType Directory -Force -ErrorAction SilentlyContinue
                    $null = Export-AzAutomationRunbook -ResourceGroupName $($competitor.resourceGroupName) -AutomationAccountName $AutomationAccount.AutomationAccountName -Name $Runbook.Name -Slot 'Published' -OutputFolder "\work\marking\$($competitor.Name)\" -Force -ErrorAction SilentlyContinue
                    # Check if file contains string
                    if ($(Get-Content -Path "\work\marking\$($competitor.name)\$($Runbook.Name).ps1") -like '*Remove-Item*temp*Force*') {
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
                    Write-Host -BackgroundColor Green "$($Competitor.Name): B3.2 - 1 - Runbook $($Runbook.Name) contains *Remove-Item*temp*Force*"
                }
                else {
                    Write-Host -BackgroundColor Red "$($Competitor.Name): B3.2 - 0 - Runbook $($Runbook.Name) does not contain *Remove-Item*temp*Force*"
                }
                if ($ScheduleMatch) {
                    Write-Host -BackgroundColor Green "$($Competitor.Name): B3.3 - 1 - Runbook $($Runbook.Name) is scheduled to run on Mondays at 04:00"
                }
                else {
                    Write-Host -BackgroundColor Red "$($Competitor.Name): B3.3 - 0 - Runbook $($Runbook.Name) is not scheduled to run on Mondays at 04:00"
                }
                # B3.4 Automaatio toimii - Automaatio tekee pyydetyt asiat palvelimella 
                # TODO Automate this
                Write-Host -BackgroundColor Yellow "$($Competitor.Name): B3.4 -   - 1 point - CHECK AUTOMATION FUNCTIONALITY!"

            }
            else {
                Write-Host -BackgroundColor Red "$($Competitor.Name): B3.2 - 0 - No runbooks found"
                Write-Host -BackgroundColor Red "$($Competitor.Name): B3.3 - 0 - No runbooks found"
                Write-Host -BackgroundColor Red "$($Competitor.Name): B3.4 - 0 - No runbooks found"
            }
        }
        else {
            Write-Host -BackgroundColor Red "$($Competitor.Name): B3.2 - 0 - No Automation Account found"
            Write-Host -BackgroundColor Red "$($Competitor.Name): B3.3 - 0 - No Automation Account found"
            Write-Host -BackgroundColor Red "$($Competitor.Name): B3.4 - 0 - No Automation Account found"
        }


    # B4 Azure valvonta

    # B4.1 Automaation ongelmahälytys toimii - Hälytys tulee sähköpostiin
    # Manual check in email
    $LogMonitorRules = Get-AzResource -ResourceGroupName $competitor.resourceGroupName -ResourceType microsoft.insights/scheduledqueryrules
    if ($LogMonitorRules) {
        Write-Host -BackgroundColor Yellow "$($Competitor.Name): B4.1 -   - 1 point - Log Search alert rule present. CREATE ALERT AND CHECK EMAIL!"
    }
    else {
        Write-Host -BackgroundColor Red "$($Competitor.Name): B4.1 - 0 - No Log Search alert rule found"
    }

    # B4.2 VM Insights otettu käyttöön pyydetysti VM Insights perf ja dependency arcatulla koneella
    $ArcExtensions = $null
    if ($ArcMachine) {
        $ArcExtensions = Get-AzConnectedMachineExtension -MachineName $ArcMachine.Name -ResourceGroupName $($competitor.resourceGroupName) -ErrorAction SilentlyContinue
    }
    if ($ArcExtensions.Name -contains 'AzureMonitorWindowsAgent' -and $ArcExtensions.Name -contains 'DependencyAgentWindows') {
        Write-Host -BackgroundColor Yellow "$($Competitor.Name): B4.2 -   - 1 point - Dependency Agent extension is installed on Azure Arc machine $($ArcMachine.Name). CHECK FUNCTIONALITY!"
    }
    else {
        Write-Host -BackgroundColor Red "$($Competitor.Name): B4.2 - 0 - No Dependency Agent extension found"
    }

    # B5 Moderni hallinta
    # B5.1 Windows Admin Center asennettu ja toimii Villellä - Ville pääsee kirjautumaan sisään WAC:iin
    if ($ArcExtensions.Name -contains 'AdminCenter') {
        $RBAC = Get-AzRoleAssignment -Scope $ArcMachine.Id -SignInName ville@kupla.eu -RoleDefinitionName 'Windows Admin Center Administrator Login' -ErrorAction SilentlyContinue
        if ($RBAC) {
            Write-Host -BackgroundColor Yellow "$($Competitor.Name): B5.1 -   - 1 point - Windows Admin Center extension is installed on Azure Arc machine $($ArcMachine.Name) and RBAC is ok. CHECK FUNCTIONALITY!"
        }
        else {
            Write-Host -BackgroundColor Red "$($Competitor.Name): B5.1 - 0 - Ville cannot log in to Windows Admin Center"
        }
    }
    else {
        Write-Host -BackgroundColor Red "$($Competitor.Name): B5.1 - 0 - No Windows Admin Center extension found"
    }

    # B6 Tekoäly				
    # B6.1 Open AI Service asennettu - Palvelu asennettu ja hubi luotu
    $AIServices = Get-AzResource -ResourceGroupName $competitor.resourceGroupName -ResourceType 'microsoft.cognitiveservices/accounts'
    $AIHubs = Get-AzResource -ResourceGroupName $competitor.resourceGroupName -ResourceType 'Microsoft.MachineLearningServices/workspaces'

    if ($AIServices -and $AIHubs) {
        Write-Host -BackgroundColor Green "$($Competitor.Name): B6.1 - 1 - AI Service and AI Hub are present"
    
        # B6.2 Mallit asennettu käytettäväksi - GPT ja Text embedding malli deployattu
        $deployments = @()
        foreach ($AIService in $AIServices) {
            $AIDeploymentsUri = $AIService.ResourceId + '/deployments?api-version=2023-05-01'
            $deployments = ((Invoke-AzRestMethod -Path $AIDeploymentsUri -Method GET).Content | ConvertFrom-Json).value
        }
        $b62Points = 0
        foreach ($deployment in $deployments) {
            if ($deployment.properties.model.name -eq 'gpt-4' -or $deployment.properties.model.name -eq 'text-embedding-ada-002') {
                $b62Points += 0.5
            }
        }

        if ($b62Points -gt 1) { $b62Points = 1 }

        if ($b62Points -eq 0) {
            Write-Host -BackgroundColor Red "$($Competitor.Name): B6.2 - 0 - No models deployed"
        }
        else {    
            Write-Host -BackgroundColor Green "$($Competitor.Name): B6.2 - $b62Points - Models deployed"
        }

        # B6.3 AI Search deplyattu - AI Search löytyy
        $AISearch = Get-AzResource -ResourceGroupName $competitor.resourceGroupName -ResourceType 'Microsoft.Search/searchServices'
        if ($AISearch) {
            Write-Host -BackgroundColor Green "$($Competitor.Name): B6.3 - 1 - AI Search is present"

            # B6.4 Search Index luotu oikeasta datasta - Index luotu oikeasta datasta
            Write-Host -BackgroundColor Yellow "$($Competitor.Name): B6.4 -   - 2 points - CHECK SEARCH INDEX FOR CORRECT DATA!"

            # B6.5 Custom data käytettävissä playgroundissa - Index lisätty AI Projektiin siten, että toimii playgroundissa
            Write-Host -BackgroundColor Yellow "$($Competitor.Name): B6.5 -   - 2 points - CHECK CUSTOM DATA IN PLAYGROUND!"        
        }
        else {
            Write-Host -BackgroundColor Red "$($Competitor.Name): B6.3 - 0 - No AI Search found"
            Write-Host -BackgroundColor Red "$($Competitor.Name): B6.4 - 0 - No AI Search found"
            Write-Host -BackgroundColor Red "$($Competitor.Name): B6.5 - 0 - No AI Search found"
        }

        # B6.6 Selainpohjainen chat-applikaatio käytettävissä - Chat applikaatioon pääsee sisälle
        $WebApp = Get-AzWebApp -ResourceGroupName $competitor.resourceGroupName -ErrorAction SilentlyContinue
        if ($WebApp) {
            $WebRequest = Invoke-WebRequest -Uri "https://$($WebApp.DefaultHostName)" -TimeoutSec 15 -ErrorAction SilentlyContinue
        }
        else {
            $WebRequest = $null
        }
        If ($WebRequest.content -like '*<div id="root"></div>*') {
            Write-Host -BackgroundColor Green "$($Competitor.Name): B6.6 - 1 - WebApp is present and anonymous login allowed at: https://$($WebApp.DefaultHostName)"
            # B6.7 Selainpohjainen chat-applikaatio vastaa omasta datasta - Kysyttäessä taitaja-kilpailuiden ylintä päätösvaltaa käyttävää elintä saadaan vastaukseksi jury.
            if ($AISearch) {
                Write-Host -BackgroundColor Yellow "$($Competitor.Name): B6.7 -   - 2 points - Ask: 'Mikä on Taitaja kilpailuiden ylintä päätösvaltaa käyttävä elin?' and check the answer!"
                # B6.8 Selainpohjainen chat-applikaatio vastaa oikein tuntemattomaan dataan - Kysyttäessä taitaja-kilpailuiden pääjohtajan puhelinnumeroa saadaan vastauksesi, ettei sitä löydetä
                Write-Host -BackgroundColor Yellow "$($Competitor.Name): B6.8 -   - 1 point - Ask: 'Mikä on Taitaja kilpailuiden pääjohtajan puhelinnumero?' and check the answer!"
            }
            else {
                Write-Host -BackgroundColor Red "$($Competitor.Name): B6.7 - 0 - No AI Search found"
                Write-Host -BackgroundColor Red "$($Competitor.Name): B6.8 - 0 - No AI Search found"
            }
        }            
        else {
            Write-Host -BackgroundColor Red "$($Competitor.Name): B6.6 - 0 - No Website deployed"
            Write-Host -BackgroundColor Red "$($Competitor.Name): B6.7 - 0 - No Website deployed"
            Write-Host -BackgroundColor Red "$($Competitor.Name): B6.8 - 0 - No Website deployed"
        }

    }
    else {
        Write-Host -BackgroundColor Red "$($Competitor.Name): B6.1 - 0 - No AI services or AI hubs found"
        Write-Host -BackgroundColor Red "$($Competitor.Name): B6.2 - 0 - No AI services or AI hubs found"
        Write-Host -BackgroundColor Red "$($Competitor.Name): B6.3 - 0 - No AI services or AI hubs found"
        Write-Host -BackgroundColor Red "$($Competitor.Name): B6.4 - 0 - No AI services or AI hubs found"
        Write-Host -BackgroundColor Red "$($Competitor.Name): B6.5 - 0 - No AI services or AI hubs found"
        Write-Host -BackgroundColor Red "$($Competitor.Name): B6.6 - 0 - No AI services or AI hubs found"
        Write-Host -BackgroundColor Red "$($Competitor.Name): B6.7 - 0 - No AI services or AI hubs found"
        Write-Host -BackgroundColor Red "$($Competitor.Name): B6.8 - 0 - No AI services or AI hubs found"
    }
    
    # B6.9 Villelle toimitettu yksinkertainen PDF ohjeistus - Sähköpostista löytyy yksinkertainen PDF-ohjeistus
    Write-Host -BackgroundColor Yellow "$($Competitor.Name): B6.9 -   - 1 point - CHECK EMAIL FOR PDF INSTRUCTIONS!"

}   