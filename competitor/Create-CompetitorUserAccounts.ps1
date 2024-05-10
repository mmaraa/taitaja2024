# Set the error action preference to stop the script on the first error.
#$ErrorActionPreference = 'Stop'

# Input parameters 
param (
    [Parameter(Mandatory = $true)]
    [int]$countOfCompetitors,
    [Parameter(Mandatory = $true)]
    [string]$tenantDomainName
)

# Connect to the Microsoft 365 tenant and create user accounts for the competitors.

try {
    Connect-MgGraph `
        -Scopes 'User.ReadWrite.All', 'Group.ReadWrite.All', 'Directory.AccessAsUser.All', 'PrivilegedAccess.ReadWrite.AzureADGroup' `
        -ContextScope Process `

}
catch {
    throw 'Login failed.'
}

# Create CSV for all the competitor user accounts.
$csvPath = 'competitorUserAccounts.csv'
$csvHeader = 'UserPrincipalName,ObjectId,Password'
$csvHeader | Out-File -FilePath $csvPath -Encoding utf8
# Create user accounts for the competitors.
try {
    foreach ($i in 1..$countOfCompetitors) {
        try {

            $pass = -join ((30..122) | Get-Random -Count 12 | ForEach-Object { [char]$_ })
            

            $PasswordProfile = @{
                Password                      = $pass
                ForceChangePasswordNextSignIn = $false
            }
            $user = New-MgUser `
                -UserPrincipalName "competitor-c$i@$TenantDomainName" `
                -DisplayName "Competitor c$i" `
                -GivenName "Competitor c$i" `
                -PasswordProfile $PasswordProfile `
                -MailNickname "competitorc$i" `
                -AccountEnabled

            $csvUser = "$($user.UserPrincipalName),$($user.Id),$pass"
            $csvUser | Out-File -FilePath $csvPath -Encoding utf8 -Append


        }
        catch {
            throw "Failed to create user account: competitor-c$i."
        }
        
    }

}

catch {
    throw "Failed to create user accounts. $($_.Exception)"
}