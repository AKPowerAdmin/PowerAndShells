<#
.SYNOPSIS
    Automates external user (vendor/support) creation in Active Directory.

.DESCRIPTION
    This script creates AD accounts for external users (e.g., vendors, support teams).
    Supports manual input or bulk creation via CSV. Users are assigned to a specified OU
    and can be optionally added to a security group. Validates OU and group before execution.

.PARAMETER OutputPath
    Directory where the CSV export of created user details will be saved.

.PARAMETER CSVDataFeed
    If set, prompts for a CSV file to import user data instead of manual entry.

.NOTES
    Author: AKPowerAdmin
    Version: 1.0
    Date: 2025-02-11

.LINK
    https://github.com/AKPowerAdmin/PowerAndShells

.EXAMPLE
    .\Create-ExternalUsers.ps1
    Runs the script in interactive mode, prompting for user details.

.EXAMPLE
    .\Create-ExternalUsers.ps1 -CSVDataFeed
    Imports external users from a CSV file.

.EXAMPLE
    .\Create-ExternalUsers.ps1 -OutputPath "C:\ExportedUsers"
    Creates users and exports results to the specified directory.
#>

[CmdletBinding()]
param (
    [string]$OutputPath = "C:\TEMP",
    [switch]$CSVDataFeed
)

function Generate-Username {
    do {
        $randomNumber = -join ((48..57) | Get-Random -Count 7 | ForEach-Object {[char]$_})
        $username = "f$randomNumber"
        $userExists = Get-ADUser -Filter {SamAccountName -eq $username} -ErrorAction SilentlyContinue
    } while ($userExists)
    return $username
}

function Generate-Password {
    param ([int]$length = 22)
    -join ((48..57 + 65..90 + 97..122 + 33..47 + 58..64 + 91..96 + 123..126) | Get-Random -Count $length | ForEach-Object { [char]$_ })
}

# Validate output dir
if (-not (Test-Path -Path $OutputPath)) {
    Write-Host "ERROR: Output dir '$OutputPath' not found. Exiting." -ForegroundColor Red
    exit 1
}

$TimeStamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$OutputFileName = Join-Path -Path $OutputPath -ChildPath "ExternalUser_$Timestamp.csv"
$Data = @()
$Results = @()

if ($CSVDataFeed) {
    $DataPath = Read-Host "CSV path"

    if (-not (Test-Path $DataPath)) {
        Write-Host "ERROR: CSV file not found. Exiting." -ForegroundColor Red
        exit 1
    }

    try {
        $Data = Import-Csv -Path $DataPath
        Write-Output "CSV loaded."
    } catch {
        Write-Host "ERROR: CSV import failed." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Output "Manual input mode."

    $FirstName   = Read-Host "First name"
    $LastName    = Read-Host "Last name"
    $CompanyName = Read-Host "Company name"
    $OUPath      = Read-Host "OU path"
    $GroupName   = Read-Host "Group (optional)"

    $Data += [PSCustomObject]@{ 
        FirstName   = $FirstName
        LastName    = $LastName
        CompanyName = $CompanyName
        OUPath      = $OUPath
        GroupName   = $GroupName
    }

    Write-Output "Data collected."
}

foreach ($row in $Data) {
    $FirstName   = $row.FirstName
    $LastName    = $row.LastName
    $GroupName   = $row.GroupName
    $CompanyName = $row.CompanyName
    $OUPath      = $row.OUPath
    $FullName    = "$FirstName $LastName"
    $Description = "$CompanyName Support - $FullName"
    $Username    = Generate-Username
    $Password    = Generate-Password
    
    # Validate OU
    if (-not $OUPath -or $OUPath -eq "") {
        Write-Host "ERROR: No OU provided. Skipping $FullName." -ForegroundColor Red
        continue
    }

    try {
        Get-ADOrganizationalUnit -Identity $OUPath -ErrorAction Stop | Out-Null
    } catch {
        Write-Host "ERROR: OU '$OUPath' not found. Skipping $FullName." -ForegroundColor Red
        continue
    }

    # Validate group if provided
    if ($GroupName -and $GroupName -ne "") {
        try {
            Get-ADGroup -Identity $GroupName -ErrorAction Stop | Out-Null
        } catch {
            Write-Host "ERROR: Group '$GroupName' not found. Skipping $FullName." -ForegroundColor Red
            continue
        }
    }

    # Create user
    New-ADUser `
        -SamAccountName $Username `
        -UserPrincipalName "$Username@ad.company.com" `
        -Name $Username `
        -DisplayName $Username `
        -Description $Description `
        -Path $OUPath `
        -AccountPassword (ConvertTo-SecureString $Password -AsPlainText -Force) `
        -PasswordNeverExpires $true `
        -CannotChangePassword $true `
        -Enabled $true

    # Add user to group
    if ($GroupName -and $GroupName -ne "") {
        try {
            Add-ADGroupMember -Identity $GroupName -Members $Username
        } catch {
            Write-Host "WARNING: Could not add $FullName to $GroupName." -ForegroundColor Yellow
        }
    }
  
    $Results += [PSCustomObject]@{
        Fullname = $FullName
        Username = $Username
        Password = $Password
    }

    if (Get-ADUser -Identity $Username -ErrorAction SilentlyContinue) {
        Write-Host "User $FullName created. Username: $Username" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Could not create $FullName." -ForegroundColor Red
        continue
    }
}

$Results | Export-Csv -Path $OutputFileName -NoTypeInformation
Write-Host "Exported to: $OutputFileName" -ForegroundColor Yellow