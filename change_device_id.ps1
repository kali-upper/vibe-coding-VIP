
# This script designed by 'FOTE'.
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Please run this script as Administrator!" -ForegroundColor Red
    Exit
}

# Create backup directory and timestamp
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = "$env:TEMP\DeviceIDBackup_$timestamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Write-Host "Creating backup in: $backupDir" -ForegroundColor Cyan

# Initialize rollback system
$changeLog = @()
$rollbackNeeded = $false
$rollbackSucceeded = $true

# Rollback function to restore original values if something fails
function Restore-OriginalValues {
    param (
        [Parameter(Mandatory=$true)]
        [array]$Changes
    )
    
    Write-Host "`nPerforming rollback of changes..." -ForegroundColor Yellow
    $rollbackSuccess = $true
    
    # Process changes in reverse order
    [array]::Reverse($Changes)
    
    foreach ($change in $Changes) {
        try {
            if ($change.ChangeType -eq "RegistryValue") {
                if ($change.OriginalExists) {
                    Set-ItemProperty -Path $change.Path -Name $change.Name -Value $change.OriginalValue -Force
                    Write-Host "Restored: $($change.Path)\$($change.Name) to $($change.OriginalValue)" -ForegroundColor Green
                } else {
                    Remove-ItemProperty -Path $change.Path -Name $change.Name -Force
                    Write-Host "Removed: $($change.Path)\$($change.Name)" -ForegroundColor Green
                }
            } elseif ($change.ChangeType -eq "ComputerName") {
                Rename-Computer -NewName $change.OriginalValue -Force
                Write-Host "Restored computer name to: $($change.OriginalValue)" -ForegroundColor Green
            }
        } catch {
            Write-Host "Failed to rollback $($change.Path)\$($change.Name)`: $($_.Exception.Message)" -ForegroundColor Red
            $rollbackSuccess = $false
        }
    }
    
    return $rollbackSuccess
}

# Backup current system information to file
$currentInfo = @{
    ComputerName = $env:COMPUTERNAME
    MachineId = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\SQMClient" -Name "MachineId" -ErrorAction SilentlyContinue).MachineId
    MachineGUID = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Cryptography" -Name "MachineGuid" -ErrorAction SilentlyContinue).MachineGuid
    ProductId = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "ProductId" -ErrorAction SilentlyContinue).ProductId
    ProductName = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "ProductName" -ErrorAction SilentlyContinue).ProductName
    RegisteredOwner = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "RegisteredOwner" -ErrorAction SilentlyContinue).RegisteredOwner
    RegisteredOrganization = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "RegisteredOrganization" -ErrorAction SilentlyContinue).RegisteredOrganization
}
$currentInfo | ConvertTo-Json | Out-File "$backupDir\system_info_backup.json"

# Export registry keys
try {
    reg export "HKLM\SOFTWARE\Microsoft\SQMClient" "$backupDir\SQMClient.reg" /y | Out-Null
    reg export "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata" "$backupDir\DeviceMetadata.reg" /y | Out-Null
    reg export "HKLM\SYSTEM\CurrentControlSet\Control\SystemInformation" "$backupDir\SystemInformation.reg" /y | Out-Null
    reg export "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" "$backupDir\WindowsNTCurrentVersion.reg" /y | Out-Null
    reg export "HKLM\SOFTWARE\Microsoft\Cryptography" "$backupDir\Cryptography.reg" /y | Out-Null
    # Backup user hives as well
    reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\SessionInfo" "$backupDir\SessionInfo.reg" /y | Out-Null
    reg export "HKCU\Software\Microsoft\IdentityCRL" "$backupDir\IdentityCRL.reg" /y | Out-Null
    reg export "HKCU\Software\Microsoft\Personalization" "$backupDir\Personalization.reg" /y | Out-Null
    Write-Host "Registry backups created successfully" -ForegroundColor Green
} catch {
    Write-Host "Warning: Could not create complete registry backups`: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Generate new IDs
$newDeviceID = [System.Guid]::NewGuid().ToString().ToUpper()
$newMachineGUID = [System.Guid]::NewGuid().ToString()
$newProductID = "00331-" + (Get-Random -Minimum 10000 -Maximum 99999) + "-" + (Get-Random -Minimum 10000 -Maximum 99999) + "-" + (Get-Random -Minimum 10000 -Maximum 99999)
$newComputerName = "RESET-PC-" + (Get-Random -Minimum 1000 -Maximum 9999)

# Validate computer name (15 characters max for NetBIOS compatibility)
if ($newComputerName.Length -gt 15) {
    $newComputerName = $newComputerName.Substring(0, 15)
    Write-Host "Computer name truncated to 15 characters: $newComputerName" -ForegroundColor Yellow
}

Write-Host "`nCurrent System Information:" -ForegroundColor Cyan
Write-Host "Device Name: $env:COMPUTERNAME"
Write-Host "Device ID: $($currentInfo.MachineId)"
Write-Host "Machine GUID: $($currentInfo.MachineGUID)"
Write-Host "Product ID: $($currentInfo.ProductId)"

Write-Host "`nNew IDs will be:" -ForegroundColor Yellow
Write-Host "New Device ID: $newDeviceID"
Write-Host "New Machine GUID: $newMachineGUID"
Write-Host "New Product ID: $newProductID"
Write-Host "New Computer Name: $newComputerName"

# Registry paths to modify (with type information)
$registryPaths = @(
    @{
        Path = "HKLM:\SOFTWARE\Microsoft\SQMClient"
        Name = "MachineId"
        Value = $newDeviceID
        Type = "String"
    },
    @{
        Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata"
        Name = "MachineId"
        Value = $newDeviceID
        Type = "String"
    },
    @{
        Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SystemInformation"
        Name = "ComputerHardwareId"
        Value = $newDeviceID
        Type = "String"
    },
    @{
        Path = "HKLM:\SOFTWARE\Microsoft\Cryptography"
        Name = "MachineGuid"
        Value = $newMachineGUID
        Type = "String"
    },
    @{
        Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
        Name = "ProductId"
        Value = $newProductID
        Type = "String"
    },
    @{
        Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
        Name = "ProductName"
        Value = "Windows 10 Pro"
        Type = "String"
    },
    @{
        Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
        Name = "RegisteredOwner"
        Value = "RESET"
        Type = "String"
    },
    @{
        Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
        Name = "RegisteredOrganization"
        Value = "RESET"
        Type = "String"
    }
)

# Get a list of all user SIDs
$userProfiles = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" | 
    Where-Object { $_.PSChildName -match "S-1-5-21" }

# Add user-specific registry entries to modify for each user profile
foreach ($profile in $userProfiles) {
    $sid = $profile.PSChildName
    $userHivePath = "$($profile.GetValue('ProfileImagePath'))\NTUSER.DAT"
    
    # Only process if the user hive exists
    if (Test-Path $userHivePath) {
        # Load the user's registry hive if it's not already loaded
        $hiveMounted = $false
        if (-not (Test-Path "Registry::HKEY_USERS\$sid")) {
            try {
                reg load "HKU\$sid" "$userHivePath" | Out-Null
                $hiveMounted = $true
                Write-Host "Loaded user hive for SID: $sid" -ForegroundColor Green
            } catch {
                Write-Host "Failed to load hive for SID $sid`: $($_.Exception.Message)" -ForegroundColor Red
                continue
            }
        }
        
        # Add user-specific registry paths for this user
        $registryPaths += @(
            @{
                Path = "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Explorer\SessionInfo"
                Name = "PermanentSessionId"
                Value = (Get-Random -Minimum 1 -Maximum 999)
                Type = "DWord"
                TempHive = $hiveMounted
                SID = $sid
            },
            @{
                Path = "Registry::HKEY_USERS\$sid\Software\Microsoft\IdentityCRL"
                Name = "DeviceId"
                Value = $newDeviceID
                Type = "String"
                TempHive = $hiveMounted
                SID = $sid
            },
            @{
                Path = "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist"
                Name = "MachineGuid"
                Value = $newMachineGUID
                Type = "String"
                TempHive = $hiveMounted
                SID = $sid
            }
        )
    }
}

# For current user, also update HKCU directly
$registryPaths += @(
    @{
        Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\SessionInfo"
        Name = "PermanentSessionId"
        Value = (Get-Random -Minimum 1 -Maximum 999)
        Type = "DWord"
    },
    @{
        Path = "HKCU:\Software\Microsoft\IdentityCRL"
        Name = "DeviceId"
        Value = $newDeviceID
        Type = "String"
    },
    @{
        Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist"
        Name = "MachineGuid"
        Value = $newMachineGUID
        Type = "String"
    }
)

# Update registry values
$successCount = 0
$totalChanges = $registryPaths.Count

foreach ($reg in $registryPaths) {
    try {
        # Skip if path doesn't exist and doesn't have SID information (non-user registry)
        if (-not (Test-Path $reg.Path) -and -not $reg.ContainsKey('SID')) {
            Write-Host "Path not found: $($reg.Path)" -ForegroundColor Yellow
            try {
                # Try to create the path
                New-Item -Path $reg.Path -Force | Out-Null
                
                # Create a change log entry for rollback
                $changeLog += @{
                    ChangeType = "RegistryValue"
                    Path = $reg.Path
                    Name = $reg.Name
                    OriginalExists = $false
                    OriginalValue = $null
                }
                
                # Create new property with correct type
                switch ($reg.Type) {
                    "String" { 
                        New-ItemProperty -Path $reg.Path -Name $reg.Name -Value $reg.Value -PropertyType String -Force | Out-Null 
                    }
                    "DWord" { 
                        New-ItemProperty -Path $reg.Path -Name $reg.Name -Value $reg.Value -PropertyType DWord -Force | Out-Null 
                    }
                    "QWord" { 
                        New-ItemProperty -Path $reg.Path -Name $reg.Name -Value $reg.Value -PropertyType QWord -Force | Out-Null 
                    }
                    "Binary" { 
                        New-ItemProperty -Path $reg.Path -Name $reg.Name -Value $reg.Value -PropertyType Binary -Force | Out-Null 
                    }
                    Default { 
                        New-ItemProperty -Path $reg.Path -Name $reg.Name -Value $reg.Value -PropertyType String -Force | Out-Null 
                    }
                }
                
                Write-Host "Created new registry entry: $($reg.Path)\$($reg.Name)" -ForegroundColor Green
                $successCount++
            } catch {
                Write-Host "Could not create registry path`: $($_.Exception.Message)" -ForegroundColor Red
                $rollbackNeeded = $true
                break
            }
        } else {
            # Path exists, try to get the original value for backup/rollback
            $originalExists = $false
            $originalValue = $null
            
            try {
                $regItem = Get-ItemProperty -Path $reg.Path -Name $reg.Name -ErrorAction SilentlyContinue
                if ($regItem -ne $null) {
                    $originalExists = $true
                    $originalValue = $regItem.$($reg.Name)
                    
                    # Backup current value
                    "$($reg.Path)|$($reg.Name)|$originalValue" | Out-File -FilePath "$backupDir\registry_values.txt" -Append
                    
                    # Add to change log for potential rollback
                    $changeLog += @{
                        ChangeType = "RegistryValue"
                        Path = $reg.Path
                        Name = $reg.Name
                        OriginalExists = $true
                        OriginalValue = $originalValue
                    }
                }
            } catch {
                # Property doesn't exist yet, will be created
                $originalExists = $false
                $changeLog += @{
                    ChangeType = "RegistryValue"
                    Path = $reg.Path
                    Name = $reg.Name
                    OriginalExists = $false
                    OriginalValue = $null
                }
            }
            
            # Set new value with proper type
            try {
                switch ($reg.Type) {
                    "String" { 
                        Set-ItemProperty -Path $reg.Path -Name $reg.Name -Value $reg.Value -Type String -Force 
                    }
                    "DWord" { 
                        Set-ItemProperty -Path $reg.Path -Name $reg.Name -Value $reg.Value -Type DWord -Force 
                    }
                    "QWord" { 
                        Set-ItemProperty -Path $reg.Path -Name $reg.Name -Value $reg.Value -Type QWord -Force 
                    }
                    "Binary" { 
                        Set-ItemProperty -Path $reg.Path -Name $reg.Name -Value $reg.Value -Type Binary -Force 
                    }
                    Default { 
                        Set-ItemProperty -Path $reg.Path -Name $reg.Name -Value $reg.Value -Force 
                    }
                }
                
                # Verify change
                $newValue = (Get-ItemProperty -Path $reg.Path -Name $reg.Name -ErrorAction SilentlyContinue).$($reg.Name)
                if ($newValue -eq $reg.Value) {
                    Write-Host "Updated $($reg.Path)\$($reg.Name)" -ForegroundColor Green
                    $successCount++
                } else {
                    Write-Host "Failed to verify change for $($reg.Path)\$($reg.Name)" -ForegroundColor Red
                    $rollbackNeeded = $true
                    break
                }
            } catch {
                Write-Host "Failed to update $($reg.Path)\$($reg.Name)`: $($_.Exception.Message)" -ForegroundColor Red
                $rollbackNeeded = $true
                break
            }
        }
    } catch {
        Write-Host "Error processing $($reg.Path)\$($reg.Name)`: $($_.Exception.Message)" -ForegroundColor Red
        $rollbackNeeded = $true
        break
    }
}

# Change computer name if no rollback is needed
if (-not $rollbackNeeded) {
    try {
        # Add to change log for potential rollback
        $changeLog += @{
            ChangeType = "ComputerName"
            OriginalValue = $env:COMPUTERNAME
        }
        
        Rename-Computer -NewName $newComputerName -Force
        Write-Host "Computer name will be changed to: $newComputerName" -ForegroundColor Green
        $successCount++
    } catch {
        Write-Host "Failed to change computer name`: $($_.Exception.Message)" -ForegroundColor Red
        $rollbackNeeded = $true
    }

    # Update profile paths more safely
    try {
        $profileListPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
        if (Test-Path $profileListPath) {
            $subKeys = Get-ChildItem -Path $profileListPath
            foreach ($key in $subKeys) {
                try {
                    $profilePath = Get-ItemProperty -Path $key.PSPath -Name "ProfileImagePath" -ErrorAction SilentlyContinue
                    if ($profilePath -and $profilePath.ProfileImagePath) {
                        # Backup original path
                        "$($key.PSPath)|ProfileImagePath|$($profilePath.ProfileImagePath)" | Out-File -FilePath "$backupDir\profile_paths.txt" -Append
                        
                        # Add to change log for potential rollback
                        $changeLog += @{
                            ChangeType = "RegistryValue"
                            Path = $key.PSPath
                            Name = "ProfileImagePath"
                            OriginalExists = $true
                            OriginalValue = $profilePath.ProfileImagePath
                        }
                        
                        # Only replace if old computer name is in the path
                        if ($profilePath.ProfileImagePath -like "*$env:COMPUTERNAME*") {
                            $newPath = $profilePath.ProfileImagePath.Replace($env:COMPUTERNAME, $newComputerName)
                            Set-ItemProperty -Path $key.PSPath -Name "ProfileImagePath" -Value $newPath
                            Write-Host "Updated profile path: $newPath" -ForegroundColor Green
                        }
                    }
                } catch {
                    Write-Host "Failed to update profile path`: $($_.Exception.Message)" -ForegroundColor Red
                    $rollbackNeeded = $true
                    break
                }
            }
        }
    } catch {
        Write-Host "Failed to update profile paths`: $($_.Exception.Message)" -ForegroundColor Red
        $rollbackNeeded = $true
    }
}

# Check if rollback is needed
if ($rollbackNeeded) {
    Write-Host "`nSome operations failed. Rolling back changes..." -ForegroundColor Red
    $rollbackSucceeded = Restore-OriginalValues -Changes $changeLog
    
    if ($rollbackSucceeded) {
        Write-Host "Rollback completed successfully." -ForegroundColor Green
    } else {
        Write-Host "WARNING: Some rollback operations failed!" -ForegroundColor Red
        Write-Host "System may be in an inconsistent state." -ForegroundColor Red
        Write-Host "Manual restoration from backup may be required: $backupDir" -ForegroundColor Red
    }
    
    # Unload any temporarily mounted hives
    foreach ($reg in $registryPaths) {
        if ($reg.ContainsKey('TempHive') -and $reg.TempHive -eq $true) {
            try {
                reg unload "HKU\$($reg.SID)" | Out-Null
                Write-Host "Unloaded user hive for SID`: $($reg.SID)" -ForegroundColor Green
            } catch {
                Write-Host "Failed to unload hive for SID $($reg.SID)`: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    
    Write-Host "`nOperation aborted. No changes were made." -ForegroundColor Red
    Exit
}

# Unload any temporarily mounted hives
foreach ($reg in $registryPaths) {
    if ($reg.ContainsKey('TempHive') -and $reg.TempHive -eq $true) {
        try {
            reg unload "HKU\$($reg.SID)" | Out-Null
            Write-Host "Unloaded user hive for SID`: $($reg.SID)" -ForegroundColor Green
        } catch {
            Write-Host "Failed to unload hive for SID $($reg.SID)`: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Completion status
Write-Host "`n=================================================" -ForegroundColor Cyan
$percentComplete = [math]::Round(($successCount / ($totalChanges + 1)) * 100)
Write-Host "CHANGES COMPLETE: $percentComplete% Success Rate" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "`nBackup created at: $backupDir" -ForegroundColor Cyan
Write-Host "`nIMPORTANT: System must restart for all changes to take effect." -ForegroundColor Yellow
Write-Host "After restart, your system will have:" -ForegroundColor Yellow
Write-Host "- New Device ID: $newDeviceID" -ForegroundColor Yellow
Write-Host "- New Machine GUID: $newMachineGUID" -ForegroundColor Yellow
Write-Host "- New Product ID: $newProductID" -ForegroundColor Yellow
Write-Host "- New Computer Name: $newComputerName" -ForegroundColor Yellow

# Create restore script
$restoreScriptPath = "$backupDir\restore_original_values.ps1"
@"
# Run as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Please run this script as Administrator!" -ForegroundColor Red
    Exit
}

# Import registry backups
Write-Host "Restoring registry backups..." -ForegroundColor Cyan
reg import "$backupDir\SQMClient.reg"
reg import "$backupDir\DeviceMetadata.reg"
reg import "$backupDir\SystemInformation.reg"
reg import "$backupDir\WindowsNTCurrentVersion.reg"
reg import "$backupDir\Cryptography.reg"
reg import "$backupDir\SessionInfo.reg"
reg import "$backupDir\IdentityCRL.reg"
reg import "$backupDir\Personalization.reg"

# Restore computer name
Rename-Computer -NewName "$($currentInfo.ComputerName)" -Force
Write-Host "Computer name will be restored to: $($currentInfo.ComputerName)" -ForegroundColor Green

Write-Host "System restoration complete. Please restart your computer." -ForegroundColor Green
"@ | Out-File -FilePath $restoreScriptPath -Encoding ASCII

Write-Host "`nA restore script has been created at: $restoreScriptPath" -ForegroundColor Cyan
Write-Host "You can run this script to restore your original settings if needed." -ForegroundColor Cyan

# Cleanup
Remove-Variable -Name currentInfo, newDeviceID, newMachineGUID, newProductID, newComputerName, registryPaths, successCount, totalChanges, changeLog, rollbackNeeded, rollbackSucceeded -ErrorAction SilentlyContinue

# Prompt for restart
$restart = Read-Host "`nWould you like to restart now? (y/n)"
if ($restart -eq 'y' -or $restart -eq 'Y') {
    Write-Host "Restarting system in 10 seconds..." -ForegroundColor Red
    Start-Sleep -Seconds 10
    Restart-Computer -Force
} else {
    Write-Host "Remember to restart your system manually for changes to take effect." -ForegroundColor Yellow 
} 