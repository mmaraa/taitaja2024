<#
.SYNOPSIS
Creates locked file in c:\temp on Azure Arc connected machines and starts runbooks on Azure Automation Hybrid Workers.

.DESCRIPTION
Creates locked file in c:\temp on Azure Arc connected machines and starts runbooks on Azure Automation Hybrid Workers.

.PARAMETER csvPath
The path to the CSV file containing competitor information. Default value is '.\competitors.csv'.

.PARAMETER subscriptionId
The subscription ID to use for the checks.

.NOTES
Author: Mika Vilpo
Date: 2024-05-17

.EXAMPLE
.\Test-AutomationTask.ps1 -resourceGroupName 'rg-competitor-k1-Taitaja2024-prod-001' -subscriptionId '00000000-0000-0000-0000-000000000000'
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $resourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]
    $markingLockScriptUri = 'https://satempwebkupla.blob.core.windows.net/marking/Add-LockedFile.ps1',

    [Parameter(Mandatory = $true)]
    [string]
    $subscriptionId 
)
# Requires Az module
# Resuires Az.ConnectedMachine module

# check that we are connected to azure
if (-not (Get-AzContext)) {
    Connect-AzAccount
}

# switch to correct subscription
$null = Set-AzContext -SubscriptionId $subscriptionId

$ArcMachines = Get-AzConnectedMachine -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue

foreach ($ArcMachine in $ArcMachines) {
    if ($ArcMachine.Status -eq 'Connected') {
        Write-Output "$($Competitor.Name): Arc connected. Creating locked file in c:\temp on $($ArcMachine.Name)"
        New-AzConnectedMachineRunCommand -ResourceGroupName $competitor.resourceGroupName -MachineName $ArcMachine.Name -RunCommandName LockFile -Location $ArcMachine.Location -SourceScriptUri $markingLockScriptUri        
    
        $AutomationAccount = Get-AzAutomationAccount -ResourceGroupName $($competitor.resourceGroupName) -ErrorAction SilentlyContinue
        if ($AutomationAccount) {
            $AutomationRunbook = Get-AzAutomationRunbook -ResourceGroupName $($competitor.resourceGroupName) -AutomationAccount $AutomationAccount.AutomationAccountName -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike 'AzureAutomationTutorialWithIdentity*' -and $_.State -like 'Published' } | Select-Object Name, State
                if ($AutomationRunbook) {
                foreach ($Runbook in $AutomationRunbook) {
                    $Schedule = Get-AzAutomationScheduledRunbook -ResourceGroupName $($competitor.resourceGroupName) -AutomationAccountName $AutomationAccount.AutomationAccountName -RunbookName $Runbook.Name -ErrorAction SilentlyContinue
                    if ($Schedule.HybridWorker) {
                        Write-Output "Starting $($Runbook.Name) on $($Schedule.HybridWorker)"
                        Start-AzAutomationRunbook -ResourceGroupName $competitor.resourceGroupName -AutomationAccountName $AutomationAccount.AutomationAccountName -Name  $runbook.Name -RunOn $Schedule.HybridWorker -ErrorAction SilentlyContinue   
                    }
                }
            }
        }
    }
}