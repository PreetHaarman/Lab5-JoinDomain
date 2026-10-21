

<#
.SYNOPSIS
    Joins computers from a CSV file to an Active Directory domain.

.DESCRIPTION
    Reads computer names from a CSV file, joins them to the domain,
    restarts the computers, verifies the join, and creates a report.

.PARAMETER CsvPath
    Path to the CSV file containing computer names.

.PARAMETER DomainName
    Name of the domain to join.

.PARAMETER ReportPath
    Path of the CSV report.

.NOTES
    Author: Harman
    Version: 1.0
#>

# Parameters
$CsvPath = "C:\Scripts\Computers.csv"
$DomainName = "Harman.powershell.com"
$ReportPath = "C:\Scripts\JoinReport.csv"

# Get credentials
$DomainCredential = Get-Credential -Message "Enter domain administrator credentials"
$LocalCredential = Get-Credential -Message "Enter target computer local administrator credentials"

# Read computers from CSV
$Computers = Import-Csv -Path $CsvPath

# Create results
$Results = foreach ($Computer in $Computers) {

    $ComputerName = $Computer.ComputerName

    # Join computer to domain
    Add-Computer -ComputerName $ComputerName `
        -DomainName $DomainName `
        -Credential $DomainCredential `
        -LocalCredential $LocalCredential `
        -Force

    # Restart computer
    Restart-Computer -ComputerName $ComputerName `
        -Credential $LocalCredential `
        -Force -Wait -For Wmi -Timeout 600 -Delay 5

    # Verify domain membership
    $Status = Get-WmiObject -Class Win32_ComputerSystem `
        -ComputerName $ComputerName `
        -Credential $LocalCredential

    if ($Status.PartOfDomain -and $Status.Domain -eq $DomainName) {
        $JoinStatus = "Joined"
        $Message = "Joined to $DomainName"
        $Restarted = "Yes"
    }
    else {
        $JoinStatus = "VerificationFailed"
        $Message = "Domain join could not be verified"
        $Restarted = "Yes"
    }

    # Create report entry
    [PSCustomObject]@{
        ComputerName = $ComputerName
        Status       = $JoinStatus
        Restarted    = $Restarted
        Message      = $Message
        Timestamp    = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
}

# Export report
$Results | Export-Csv -Path $ReportPath -NoTypeInformation

# Display results
$Results | Format-Table -AutoSize

Write-Host "Report saved to $ReportPath"

