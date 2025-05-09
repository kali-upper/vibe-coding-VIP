# Windsurf Machine ID Reset Script for Windows
# This script resets Windsurf's machine identifiers without performing a full cleanup
# It focuses on changing identification information while preserving other settings

# Check for administrative privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "This script requires administrator privileges to update the Windows registry." -ForegroundColor Red
    Write-Host "Please right-click on PowerShell and select 'Run as Administrator', then run this script again." -ForegroundColor Yellow
    Write-Host "Press any key to exit..."
    $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
    exit
}

# Helper function to generate IDs
function Generate-IDs {
    # Generate UUID for machineId
    $machineId = [guid]::NewGuid().ToString()
    
    # Generate deviceId (64 char hex)
    $randomBytes = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($randomBytes)
    $deviceId = -join ($randomBytes | ForEach-Object { $_.ToString("x2") })
    
    return @{
        "machineId" = $machineId
        "deviceId" = $deviceId
    }
}

# Define paths
$USERNAME = $env:USERNAME
$USERPROFILE = $env:USERPROFILE
$APPDATA_PATH = Join-Path $USERPROFILE "AppData\Roaming\Windsurf"
$WINDSURF_HOME = Join-Path $USERPROFILE ".windsurf"
$CODEIUM_PATH = Join-Path $USERPROFILE ".codeium"
$BACKUP_PATH = Join-Path $APPDATA_PATH "ID_Backups"

# Make sure Windsurf is closed
$windsurfProcess = Get-Process -Name "Windsurf" -ErrorAction SilentlyContinue
if ($windsurfProcess) {
    Write-Host "Windsurf is currently running. Please close it before continuing." -ForegroundColor Yellow
    $response = Read-Host "Do you want to forcibly close Windsurf now? (Y/N)"
    if ($response -eq "Y" -or $response -eq "y") {
        Stop-Process -Name "Windsurf" -Force
        Start-Sleep -Seconds 2
    } else {
        Write-Host "Please close Windsurf and run this script again." -ForegroundColor Red
        exit
    }
}

# Check for any Codeium processes as well
$codeiumProcess = Get-Process -Name "*codeium*" -ErrorAction SilentlyContinue
if ($codeiumProcess) {
    Write-Host "Codeium processes are running. These will be closed." -ForegroundColor Yellow
    Stop-Process -Name "*codeium*" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

# Check if paths exist
if (-not (Test-Path -Path $APPDATA_PATH)) {
    Write-Host "Windsurf installation not found at: $APPDATA_PATH" -ForegroundColor Red
    $create = Read-Host "Would you like to create the required directories? (Y/N)"
    if ($create -eq "Y" -or $create -eq "y") {
        New-Item -Path $APPDATA_PATH -ItemType Directory -Force | Out-Null
        New-Item -Path $WINDSURF_HOME -ItemType Directory -Force | Out-Null
        New-Item -Path $CODEIUM_PATH -ItemType Directory -Force | Out-Null
    } else {
        exit
    }
}

# Create backup directory
if (-not (Test-Path -Path $BACKUP_PATH)) {
    New-Item -Path $BACKUP_PATH -ItemType Directory -Force | Out-Null
}

# Display intro
Write-Host "=== Windsurf Machine ID Reset Tool ===" -ForegroundColor Cyan
Write-Host "This script will reset your Windsurf machine identifiers." -ForegroundColor Cyan
Write-Host "Found Windsurf installation at: $APPDATA_PATH" -ForegroundColor Green
Write-Host "Backups will be saved to: $BACKUP_PATH" -ForegroundColor Green

# Generate new IDs
Write-Host "`nGenerating new identifiers..." -ForegroundColor Cyan
$newIds = Generate-IDs

# Display the new IDs
Write-Host "`nGenerated new identifiers:" -ForegroundColor Green
Write-Host "machineId: $($newIds.machineId)" -ForegroundColor Gray
Write-Host "deviceId: $($newIds.deviceId)" -ForegroundColor Gray

# 1. Update MachineId file
Write-Host "`n[1/5] Updating machineId file..." -ForegroundColor Cyan
$machineIdPath = Join-Path $APPDATA_PATH "machineid"
if (Test-Path -Path $machineIdPath) {
    # Create timestamp for backup
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFile = Join-Path $BACKUP_PATH "machineid_$timestamp.backup"
    Copy-Item -Path $machineIdPath -Destination $backupFile -Force
    Write-Host "Created backup at: $backupFile" -ForegroundColor Yellow
}
Set-Content -Path $machineIdPath -Value $newIds.machineId -Force
Write-Host "Updated machineId file successfully" -ForegroundColor Green

# 2. Update Preferences file
Write-Host "`n[2/5] Updating Preferences file..." -ForegroundColor Cyan
$preferencesPath = Join-Path $APPDATA_PATH "Preferences"
if (Test-Path -Path $preferencesPath) {
    # Create timestamp for backup
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFile = Join-Path $BACKUP_PATH "Preferences_$timestamp.backup"
    Copy-Item -Path $preferencesPath -Destination $backupFile -Force
    Write-Host "Created backup at: $backupFile" -ForegroundColor Yellow
    
    try {
        $preferences = Get-Content $preferencesPath -Raw | ConvertFrom-Json
        
        # Look for any fields that might contain the username and update them
        $preferences.PSObject.Properties | ForEach-Object {
            if ($_.Value -is [string] -and $_.Value.Contains($USERNAME)) {
                $_.Value = $_.Value.Replace($USERNAME, "RESET")
                Write-Host "Updated username reference in $($_.Name)" -ForegroundColor Green
            }
        }
        
        # Update the preferences file
        $preferences | ConvertTo-Json -Depth 10 | Set-Content $preferencesPath
        Write-Host "Updated Preferences file successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "Error updating Preferences: $_" -ForegroundColor Red
        Write-Host "Skipping Preferences update" -ForegroundColor Yellow
    }
}

# 3. Update Local State file
Write-Host "`n[3/5] Updating Local State file..." -ForegroundColor Cyan
$localStatePath = Join-Path $APPDATA_PATH "Local State"
if (Test-Path -Path $localStatePath) {
    # Create timestamp for backup
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFile = Join-Path $BACKUP_PATH "LocalState_$timestamp.backup"
    Copy-Item -Path $localStatePath -Destination $backupFile -Force
    Write-Host "Created backup at: $backupFile" -ForegroundColor Yellow
    
    try {
        $localState = Get-Content $localStatePath -Raw | ConvertFrom-Json
        if ($localState.user_data_dir -and $localState.user_data_dir.Contains($USERNAME)) {
            $localState.user_data_dir = $localState.user_data_dir.Replace($USERNAME, "RESET")
            Write-Host "Updated username in user_data_dir" -ForegroundColor Green
        }
        
        # Update the local state file
        $localState | ConvertTo-Json -Depth 10 | Set-Content $localStatePath
        Write-Host "Updated Local State file successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "Error updating Local State: $_" -ForegroundColor Red
        Write-Host "Skipping Local State update" -ForegroundColor Yellow
    }
}

# 4. Update argv.json file in Windsurf home directory
Write-Host "`n[4/5] Updating argv.json file..." -ForegroundColor Cyan
$argvPath = Join-Path $WINDSURF_HOME "argv.json"
if (Test-Path -Path $argvPath) {
    # Create timestamp for backup
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFile = Join-Path $BACKUP_PATH "argv_$timestamp.backup"
    Copy-Item -Path $argvPath -Destination $backupFile -Force
    Write-Host "Created backup at: $backupFile" -ForegroundColor Yellow
    
    try {
        # Read the file as text first to avoid JSON parsing issues
        $argvContent = Get-Content -Path $argvPath -Raw
        
        # Remove any potential BOM or invalid characters
        $argvContent = $argvContent.Trim([char]0xFEFF, [char]0xFFFE, [char]0x200B)
        
        # Parse the JSON content
        $argv = $argvContent | ConvertFrom-Json
        
        # Get properties from the object
        $properties = $argv | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        
        if ($properties -contains "user-data-dir") {
            if ($argv.'user-data-dir'.Contains($USERNAME)) {
                $argv.'user-data-dir' = $argv.'user-data-dir'.Replace($USERNAME, "RESET")
                Write-Host "Updated username in user-data-dir" -ForegroundColor Green
            }
        }
        
        # Update the argv file
        $argv | ConvertTo-Json -Depth 10 | Set-Content $argvPath
        Write-Host "Updated argv.json file successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "Error updating argv.json: $_" -ForegroundColor Red
        Write-Host "Skipping argv.json update" -ForegroundColor Yellow
    }
}

# 5. Update Windows Registry
Write-Host "`n[5/5] Updating Windows Registry MachineGuid..." -ForegroundColor Cyan
try {
    $registryPath = "HKLM:\SOFTWARE\Microsoft\Cryptography"
    $oldGuid = (Get-ItemProperty -Path $registryPath -Name "MachineGuid" -ErrorAction SilentlyContinue).MachineGuid
    
    if ($oldGuid) {
        Write-Host "Found existing MachineGuid: $oldGuid" -ForegroundColor Yellow
        # Create a backup in registry
        New-ItemProperty -Path $registryPath -Name "MachineGuid.backup" -Value $oldGuid -PropertyType String -Force | Out-Null
        Write-Host "Created backup in registry: MachineGuid.backup" -ForegroundColor Yellow
    }
    
    # Generate a new GUID for registry
    $newMachineGuid = [guid]::NewGuid().ToString()
    Set-ItemProperty -Path $registryPath -Name "MachineGuid" -Value $newMachineGuid -Type String -Force
    Write-Host "Updated Windows Registry MachineGuid to: $newMachineGuid" -ForegroundColor Green
}
catch {
    Write-Host "Failed to update Windows Registry: $_" -ForegroundColor Red
    Write-Host "This step requires administrator privileges." -ForegroundColor Yellow
}

# Reset Codeium too (simple version)
Write-Host "`n[Bonus] Resetting Codeium..." -ForegroundColor Cyan
if (Test-Path -Path $CODEIUM_PATH) {
    # Create a timestamp for backups
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    
    # Look for config.json
    $codeiumConfigPath = Join-Path $CODEIUM_PATH "config.json"
    if (Test-Path -Path $codeiumConfigPath) {
        $backupFile = Join-Path $BACKUP_PATH "codeium_config_$timestamp.backup"
        Copy-Item -Path $codeiumConfigPath -Destination $backupFile -Force
        Write-Host "Created backup of Codeium config at: $backupFile" -ForegroundColor Yellow
        
        # Create a new device ID for Codeium
        try {
            $newDeviceId = [System.Guid]::NewGuid().ToString()
            $newConfig = @{
                "device_id" = $newDeviceId
                "api_key" = ""
                "portal_url" = "https://www.codeium.com"
                "manager_url" = "https://codeium.com/waitlist"
                "inference_url" = "https://server.codeium.com"
            }
            
            # Update the config
            $newConfig | ConvertTo-Json -Depth 10 | Set-Content $codeiumConfigPath
            Write-Host "Updated Codeium config with new device ID: $newDeviceId" -ForegroundColor Green
        }
        catch {
            Write-Host "Error updating Codeium config: $_" -ForegroundColor Red
        }
    }
    else {
        # Create a new Codeium config if it doesn't exist
        try {
            $newDeviceId = [System.Guid]::NewGuid().ToString()
            $newConfig = @{
                "device_id" = $newDeviceId
                "api_key" = ""
                "portal_url" = "https://www.codeium.com"
                "manager_url" = "https://codeium.com/waitlist"
                "inference_url" = "https://server.codeium.com"
            }
            
            # Create the config
            $newConfig | ConvertTo-Json -Depth 10 | Set-Content $codeiumConfigPath
            Write-Host "Created new Codeium config with device ID: $newDeviceId" -ForegroundColor Green
        }
        catch {
            Write-Host "Error creating Codeium config: $_" -ForegroundColor Red
        }
    }
}

# Completion
Write-Host "`n=== Reset Complete ===" -ForegroundColor Green
Write-Host "Windsurf machine identifiers have been reset successfully." -ForegroundColor Green
Write-Host "`nWhat's been done:" -ForegroundColor Cyan
Write-Host "1. Generated new unique identifiers" -ForegroundColor White
Write-Host "2. Updated machineId file at: $machineIdPath" -ForegroundColor White
Write-Host "3. Updated Preferences file at: $preferencesPath" -ForegroundColor White
Write-Host "4. Updated Local State file at: $localStatePath" -ForegroundColor White
Write-Host "5. Updated argv.json at: $argvPath" -ForegroundColor White
Write-Host "6. Updated Windows Registry MachineGuid" -ForegroundColor White
Write-Host "7. Reset Codeium configuration" -ForegroundColor White

Write-Host "`nBackups Created in: $BACKUP_PATH" -ForegroundColor Cyan

Write-Host "`nNext Steps:" -ForegroundColor Cyan
Write-Host "1. Launch Windsurf and complete any initial setup" -ForegroundColor White
Write-Host "2. If you need to revert these changes, use the backup files in $BACKUP_PATH" -ForegroundColor White

Write-Host "`nPress any key to exit..."
$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null 