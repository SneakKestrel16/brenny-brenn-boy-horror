# Updates this folder in place from the latest GitHub release. Run by Update.bat, Host.bat and Join.bat.
# Never throws: a failed check prints one line and the installed build still starts.
param([string]$Api = 'https://api.github.com/repos/SneakKestrel16/brenny-brenn-boy-horror/releases/latest')
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $build = Join-Path $PSScriptRoot 'BUILD.txt'
    $local = if (Test-Path -LiteralPath $build) { (Get-Content -LiteralPath $build -TotalCount 1).Trim() } else { '' }
    $rel = Invoke-RestMethod -Uri $Api -Headers @{ 'User-Agent' = 'bbbh-updater' } -TimeoutSec 15
    if ($rel.tag_name -eq $local) { Write-Host "Game is up to date ($local)."; exit 0 }
    if (Get-Process -Name 'Brenny Brenn Boy Horror*' -ErrorAction SilentlyContinue) {
        Write-Host "A newer build ($($rel.tag_name)) exists. Close the game, then run Update.bat."; exit 0
    }
    $asset = $rel.assets | Where-Object { $_.name -eq 'brenny_playtest.zip' } | Select-Object -First 1
    if (-not $asset) { throw "release $($rel.tag_name) has no brenny_playtest.zip" }
    Write-Host "Updating $local -> $($rel.tag_name) ($([math]::Round($asset.size / 1MB)) MB)..."
    $tmp = Join-Path $env:TEMP 'bbbh_update'
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    New-Item -ItemType Directory -Path $tmp | Out-Null
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile "$tmp\u.zip" -Headers @{ 'User-Agent' = 'bbbh-updater' }
    Expand-Archive -LiteralPath "$tmp\u.zip" -DestinationPath "$tmp\x"
    $src = Join-Path $tmp 'x\brenny_playtest'
    # A running .bat is read by byte offset, so replacing one mid-run can break it: existing .bat files stay.
    Get-ChildItem -LiteralPath $src -Recurse -File | ForEach-Object {
        $to = Join-Path $PSScriptRoot $_.FullName.Substring($src.Length + 1)
        if ($_.Extension -eq '.bat' -and (Test-Path -LiteralPath $to)) { return }
        New-Item -ItemType Directory -Path (Split-Path $to) -Force | Out-Null
        Copy-Item -LiteralPath $_.FullName -Destination $to -Force
    }
    Remove-Item -LiteralPath $tmp -Recurse -Force
    Write-Host "Updated to $($rel.tag_name)."
} catch {
    Write-Host "Update check failed ($($_.Exception.Message)). Starting the installed build."
}
