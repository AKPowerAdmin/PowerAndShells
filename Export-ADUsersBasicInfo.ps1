<#
.SYNOPSIS
    Export user data form AD to a CSV file.

.DESCRIPTION
    This script retrieves users from a specific OU in AD, checks if their accounts are disabled, and exports selected details to a CSV file.

.PARAMETER SearchBase
    The distinguished name of the OU to search for users.
    
.PARAMETER OutputPath
    The file patch to save the exported CSV file.

.PARAMETER Detailed
    Switch to export detailed user information.

.NOTES
    Author: Albert Kosinski
    Version: 1.0
    Date: 2024-12-17
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$SearchBase,
    [string]$OutputPath = "C:\temp",
    [switch]$Detailed
)

$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$OutputFileName = Join-Path -Path $OutputPath -ChildPath "UserInfo_$Timestamp.csv"

if (-not (Test-Path -Path $OutputPath)) {
    Write-Output "The directory '$OutputPath' does not exist. Creating it now..."
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

try {
    if ($Detailed) {
        Write-Output "Exporting detailed user(s) information..."
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
                Name = "manager";
                Expression = { $_.manager -replace '^CN=([^,]+),.*$', '$1' }},
            "mobile", "telephoneNumber", "company", "street", "l", "st", 
            "PostalCode", "c",
            @{
                Name       = "Enabled";
                Expression = { ($_.userAccountControl -band 2) -eq 0 }},
            "DistinguishedName"
        )
    } else {
        Write-Output "Exporting basic user(s) information..."
        $Properties = "userAccountControl", "givenName", "sn", "sAMAccountName"
        $SelectAttributes = @(
            "sAMAccountName", "givenName", "sn", 
            @{
                Name       = "Enabled";
                Expression = { ($_.userAccountControl -band 2) -eq 0 }}
        )
    }

    $users = Get-ADUser -Filter * -SearchBase $SearchBase -Properties $Properties |
    Select-Object $SelectAttributes
    $users | Export-Csv -Path $OutputFileName -Delimiter "," -Encoding unicode -NoTypeInformation
    Write-Output "Data of $($Users.Count) user(s) successfully exported to: $OutputFileName"

}
catch {
    Write-Error "An error occurred: $_ "
}