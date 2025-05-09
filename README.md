# Machine ID Reset Tools

This collection of PowerShell scripts helps you reset device identifiers for Cursor and Windsurf code editors, and change Windows device IDs.

## What These Tools Do

When you use software applications, they often create unique IDs to identify your computer. Sometimes you need to reset these IDs to fix licensing issues or start fresh. These scripts do that automatically for you.

## Available Scripts

### 1. Reset Cursor ID (reset_cursor_windows-v0.1.ps1)

**What it does:** Creates new IDs for the Cursor code editor

**Simple steps:**

- Creates fresh identification numbers
- Updates all necessary files and settings
- Makes backups of your original settings

**Before running:**

- Close Cursor completely
- Run PowerShell as Administrator

### 2. Reset Windsurf ID (reset_windsurf_windows-v0.1.ps1)

**What it does:** Creates new IDs for the Windsurf code editor

**Simple steps:**

- Creates fresh identification numbers
- Updates configuration files
- Makes backup copies with timestamps
- Also resets Codeium settings

**Before running:**

- Close Windsurf completely
- Run PowerShell as Administrator

### 3. Change Windows Device ID (change_device_id.ps1)

**What it does:** Changes your computer's system-wide identification numbers

**Simple steps:**

- Changes Windows device IDs
- Updates registry settings
- Changes computer name
- Creates backups you can restore if needed

**Before running:**

- Run PowerShell as Administrator
- You may need to restart your computer afterward

## How to Use These Tools

1. **Open PowerShell as Administrator**

   - Right-click on PowerShell
   - Select "Run as Administrator"

2. **Go to the folder with these scripts**

   - Use the `cd` command (example: `cd C:\Downloads\MachineIDTools`)

3. **Run the script you need**

   - For Cursor: `.\reset_cursor_windows-v0.1.ps1`
   - For Windsurf: `.\reset_windsurf_windows-v0.1.ps1`
   - For Windows IDs: `.\change_device_id.ps1`

4. **Follow the on-screen instructions**
   - The script will guide you through the process
   - It will create backups automatically

## Important Notes

- **Always run as Administrator** - These scripts need special permissions
- **Backups are created automatically** - Your original settings are saved
- **May require restart** - Some changes only take effect after restarting
- **Use at your own risk** - While safe when used correctly, these scripts modify system settings

## Files Included

- `reset_cursor_windows-v0.1.ps1` - Resets Cursor IDs
- `reset_windsurf_windows-v0.1.ps1` - Resets Windsurf IDs
- `change_device_id.ps1` - Changes Windows device IDs
- `CursorFreeVIP_1.8.08_windows.exe` - Cursor editor installer
