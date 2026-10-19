<#
.SYNOPSIS
    Joins computers from a CSV file to a domain remotely and makes a report.
.DESCRIPTION
    This script reads computer names from a CSV file (column name: ComputerName).
    For each computer it checks the connection, joins it to the domain and restarts it.
    At the end it shows a report and saves it to a CSV file so I can see which computers
    were joined and which ones failed.
    The passwords are asked when the script runs so they are not saved in the script.
.PARAMETER CsvPath
    Path of the CSV file with the computer names. Default is C:\Scripts\Computers.csv
.PARAMETER Domain
    The domain to join. Default is Harman.powershell.com
.PARAMETER AdminUser
    The domain admin account name. Default is Harman
.PARAMETER ReportPath
    Where the report is saved. Default is C:\Scripts\JoinReport.csv
.EXAMPLE
    PS> .\Harmanpreet_JoinDomainScript.ps1
.NOTES
    Author: Harmanpreet Kaur
    Created: 2026-10-17
    Version: 1.0
    Last Modified: 2026-10-17
    Change Log:
        1.0 - Initial release
.LINK
    https://learn.microsoft.com/powershell/module/microsoft.powershell.management/add-computer
#>

#Parameters
param(
    [string]$CsvPath    = "C:\Scripts\Computers.csv",
    [string]$Domain     = "Harman.powershell.com",
    [string]$AdminUser  = "Harman",
    [string]$ReportPath = "C:\Scripts\JoinReport.csv"
)

#Functions

# Reads the CSV file and gives back the list of computer names
function Get-ComputerList($path) {
    if (-not (Test-Path $path)) {
        throw "CSV file not found: $path"
    }
    $rows = Import-Csv -Path $path
    $names = @()
    foreach ($row in $rows) {
        $name = "$($row.ComputerName)".Trim()
        if ($name -ne "") {
            $names += $name
        }
    }
    if ($names.Count -eq 0) {
        throw "No computer names found. The CSV needs a column called ComputerName."
    }
    return $names
}

# Joins one remote computer to the domain and restarts it
# It gives back one line for the report
function Join-OneComputer($pc, $localCred, $domainCred) {

    $status = ""
    $restarted = "No"
    $message = ""

    # check if the computer answers first
    if (-not (Test-Connection -ComputerName $pc -Count 1 -Quiet)) {
        $status = "Failed"
        $message = "Computer is not reachable"
    }
    else {
        try {
            Add-Computer -ComputerName $pc -LocalCredential $localCred -DomainName $Domain `
                -Credential $domainCred -Restart -Force -ErrorAction Stop
            $status = "Joined"
            $restarted = "Yes"
            $message = "Joined to $Domain"
        }
        catch {
            $status = "Failed"
            $message = $_.Exception.Message
        }
    }

    return [PSCustomObject]@{
        ComputerName = $pc
        Status       = $status
        Restarted    = $restarted
        Message      = $message
        Time         = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
}

#Execution Code

# Read the computer names
try {
    $computers = Get-ComputerList $CsvPath
}
catch {
    Write-Host "Error: $($_.Exception.Message)"
    return
}
Write-Host "Found $($computers.Count) computer(s) in the CSV file"

# Ask for the passwords
$domainCred = Get-Credential -UserName "$Domain\$AdminUser" -Message "Enter DOMAIN admin password"
$localCred  = Get-Credential -Message "Enter LOCAL admin of the remote PCs (example: PC\Administrator)"

# Join each computer and keep the result for the report
$report = @()
foreach ($pc in $computers) {
    Write-Host "Joining $pc ..."
    $report += Join-OneComputer $pc $localCred $domainCred
}

# Show the report on the screen
Write-Host ""
Write-Host "===== Join Report ====="
$report | Format-Table ComputerName, Status, Restarted, Message -AutoSize

$joined = @($report | Where-Object { $_.Status -eq "Joined" }).Count
$failed = @($report | Where-Object { $_.Status -eq "Failed" }).Count
Write-Host "Joined: $joined   Failed: $failed"

# Save the report to a CSV file
$report | Export-Csv -Path $ReportPath -NoTypeInformation
Write-Host "Report saved to $ReportPath"
