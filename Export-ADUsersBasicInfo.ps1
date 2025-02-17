<#
.SYNOPSIS
    Export AD users to CSV.

.DESCRIPTION
    Retrieves user data from a specific OU, checks account status, 
    and exports selected attributes to a CSV file. Supports detailed export.

.PARAMETER SearchBase
    Distinguished name of the OU to search for users.

.PARAMETER OutputPath
    Directory where the CSV file will be saved. Defaults to "C:\temp".

.PARAMETER Detailed
    If set, exports extended user attributes.

.NOTES
    Author: AKPowerAdmin
    Version: 1.1
    Date: 2024-12-17

.LINK
    https://github.com/AKPowerAdmin/PowerAndShells

.EXAMPLE
    .\Export-ADUsers.ps1 -SearchBase "OU=Users,DC=ad,DC=example,DC=com"
    Exports basic user data from the specified OU.

.EXAMPLE
    .\Export-ADUsers.ps1 -SearchBase "OU=Users,DC=ad,DC=example,DC=com" -Detailed
    Exports detailed user data including contact info, manager, and status.

.EXAMPLE
    .\Export-ADUsers.ps1 -SearchBase "OU=Users,DC=ad,DC=example,DC=com" -OutputPath "C:\Exports"
    Saves the exported CSV to the specified directory.
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$SearchBase,

    [string]$OutputPath = "C:\temp",

    [switch]$Detailed
)

$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$OutputFileName = Join-Path -Path $OutputPath -ChildPath "UserInfo_$Timestamp.csv"

# Ensure output directory exists
if (-not (Test-Path -Path $OutputPath)) {
    Write-Output "Creating output directory: $OutputPath"
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

try {
    # Define attributes for basic or detailed export
    if ($Detailed) {
        Write-Output "Exporting detailed user data..."
        $Properties = @(
            "sn", "givenName", "sAMAccountName", "mail", "employeeNumber", 
            "department", "title", "manager", "mobile", "telephoneNumber", 
            "company", "street", "l", "st", "PostalCode", "c", 
            "userAccountControl", "DistinguishedName"   
        )
        $SelectAttributes = @(
            "sn", "givenName", "sAMAccountName", "mail", "employeeNumber",
            "department", "title",
            @{
                Name       = "manager";
                Expression = { $_.manager -replace '^CN=([^,]+),.*$', '$1' }
            },
            "mobile", "telephoneNumber", "company", "street", "l", "st", 
            "PostalCode", "c",
            @{
                Name       = "Enabled";
                Expression = { ($_.userAccountControl -band 2) -eq 0 }
            },
            "DistinguishedName"
        )
    } else {
        Write-Output "Exporting basic user data..."
        $Properties = "userAccountControl", "givenName", "sn", "sAMAccountName"
        $SelectAttributes = @(
            "sAMAccountName", "givenName", "sn",
            @{
                Name       = "Enabled";
                Expression = { ($_.userAccountControl -band 2) -eq 0 }
            }
        )
    }

    # Retrieve user data from AD
    $Users = Get-ADUser -Filter * -SearchBase $SearchBase -Properties $Properties |
        Select-Object $SelectAttributes

    # Export to CSV
    $Users | Export-Csv -Path $OutputFileName -Delimiter "," -Encoding Unicode -NoTypeInformation

    Write-Output "Exported $($Users.Count) users to: $OutputFileName"
}
catch {
    Write-Error "Error: $_"
}