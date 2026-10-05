#!/bin/bash
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../lib/common.sh"
_load_config
: "${GAME_APP:?GAME_APP not set in env.sh}"
APP="$GAME_APP"

# 1. Inner PowerShell script (Core logic for window management)
read -r -d '' BRING_PS1 << 'EOF' || true
$ProgressPreference = 'SilentlyContinue'
$appName = '@@APP@@'

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, int dwExtraInfo);
}
"@

$mySession = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
$allFound = Get-Process | Where-Object { $_.ProcessName -match $appName }
$withUi = $allFound | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1

if ($withUi) {
    $hwnd = $withUi.MainWindowHandle
    
    # Bypass Windows foreground lock by simulating an ALT key press
    [Win]::keybd_event(0x12, 0, 0, 0)
    [Win]::keybd_event(0x12, 0, 2, 0)

    # Restore the window if minimized, otherwise just show it
    if ([Win]::IsIconic($hwnd)) {
        [Win]::ShowWindow($hwnd, 9)
    } else {
        [Win]::ShowWindow($hwnd, 5)
    }
    
    $res = [Win]::SetForegroundWindow($hwnd)
    "OK -> $($withUi.ProcessName) (PID $($withUi.Id)) [Focus: $res, Sess: $mySession]" | Out-File -Encoding utf8 "$HOME\front_result.txt"
} else {
    if ($allFound) {
        $details = $allFound | ForEach-Object { 
            "$($_.ProcessName) (PID:$($_.Id), Sess:$($_.SessionId), HWND:$($_.MainWindowHandle))" 
        }
        "FOUND NO UI. ScriptSess: $mySession | Target: $($details -join ' ; ')" | Out-File -Encoding utf8 "$HOME\front_result.txt"
    } else {
        "NOT FOUND: $appName" | Out-File -Encoding utf8 "$HOME\front_result.txt"
    }
}
EOF

BRING_PS1="${BRING_PS1//@@APP@@/$APP}"
PS1_B64=$(printf %s "$BRING_PS1" | base64 | tr -d '\n')

# 2. Outer driver script (Handles Session 1 execution and cleanup with clean prints)
read -r -d '' DRIVER << 'EOF' || true
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=== BEGIN EXECUTION ==="

$base   = $HOME
$result = "$base\front_result.txt"
$ps1File = "$base\bringfront.ps1"
$task   = "BringFrontTask"

Write-Host "[Step 1] Cleaning up old tasks..."
schtasks /End /TN $task 2>&1 | Out-Null
schtasks /Delete /TN $task /F 2>&1 | Out-Null

Write-Host "[Step 2] Cleaning up old files..."
if (Test-Path $result) { Remove-Item $result -Force -ErrorAction SilentlyContinue }
if (Test-Path $ps1File) { Remove-Item $ps1File -Force -ErrorAction SilentlyContinue }

Write-Host "[Step 3] Writing PS1 file..."
[IO.File]::WriteAllBytes($ps1File, [Convert]::FromBase64String('@@PS1_B64@@'))
$tr = "powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"$ps1File`""

Write-Host "[Step 4] Creating Scheduled Task..."
# Catch output and filter out the noisy NativeCommandError warning
$createRes = schtasks /Create /TN $task /TR $tr /SC ONCE /ST 00:00 /IT /F 2>&1
$cleanCreate = $createRes | ForEach-Object { $_.ToString() } | Where-Object { $_ -notmatch 'WARNING: Task may not run' } | Out-String
Write-Host "  -> $($cleanCreate.Trim())"

Write-Host "[Step 5] Running Scheduled Task..."
$runRes = schtasks /Run /TN $task 2>&1 | Out-String
Write-Host "  -> $($runRes.Trim())"

Write-Host "[Step 6] Waiting for execution (3 seconds)..."
Start-Sleep -Seconds 3

Write-Host "[Step 7] Reading result..."
if (Test-Path $result) {
    $out = Get-Content $result -Encoding UTF8
    Write-Host "  -> RESULT: $out"
} else {
    Write-Host "  -> ERROR: Result file not found! Scheduled task might have failed silently."
}

Write-Host "[Step 8] Final Cleanup..."
schtasks /Delete /TN $task /F 2>&1 | Out-Null
Remove-Item $ps1File -Force -ErrorAction SilentlyContinue

Write-Host "=== END EXECUTION ==="
EOF

DRIVER="${DRIVER//@@PS1_B64@@/$PS1_B64}"

OPT_USER=""
if [[ -n "${WIN_USER:-}" ]]; then
    OPT_USER="${WIN_USER}@"
fi

# Execute via STDIN to bypass the 8191-character command line length limit
printf "%s\n" "$DRIVER" | ssh "${OPT_USER}${REMOTE_HOST}" powershell -NoProfile -Command -
