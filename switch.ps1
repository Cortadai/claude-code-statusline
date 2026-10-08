# Points Claude Code's status line at one of the versions in this repo.
#   .\switch.ps1 v3     use v3 (backs up settings.json first)
#   .\switch.ps1        show the version in use and the ones available
# The change shows up after Claude Code's next response.
param([ValidateSet("v1", "v2", "v3", "")][string]$Version = "")

$ErrorActionPreference = "Stop"
# Windows PowerShell 5.1 rewrites settings.json with odd indentation and escaped accents; prefer pwsh when present
if ($PSVersionTable.PSVersion.Major -lt 6 -and (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    & pwsh -NoProfile -File $PSCommandPath $Version
    exit $LASTEXITCODE
}
$versions = [ordered]@{
    v1 = @{ dir = "v1-original"; shell = "powershell"; refresh = $null; about = "una fila, la original" }
    v2 = @{ dir = "v2-box";      shell = "pwsh";       refresh = 60;    about = "caja con dos filas, todo visible (necesita pwsh)" }
    v3 = @{ dir = "v3-compact";  shell = "powershell"; refresh = 60;    about = "una fila, iconos, avisos solo cuando hacen falta" }
}

$claudeDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE ".claude" }
$settingsFile = Join-Path $claudeDir "settings.json"
$settings = if (Test-Path $settingsFile) { Get-Content $settingsFile -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }

function ScriptPath($v) { (Join-Path (Join-Path $PSScriptRoot $versions[$v].dir) "statusline.ps1") -replace "\\", "/" }

if (-not $Version) {
    $current = "$($settings.statusLine.command)"
    foreach ($v in $versions.Keys) {
        $mark = if ($current -like "*$(ScriptPath $v)*") { "*" } else { " " }
        Write-Host (" {0} {1}  {2}" -f $mark, $v, $versions[$v].about)
    }
    if ($current -and $current -notlike "*$($PSScriptRoot -replace '\\', '/')*") { Write-Host "`n En uso (fuera de este repo): $current" }
    return
}

$chosen = $versions[$Version]
if (-not (Get-Command $chosen.shell -ErrorAction SilentlyContinue)) {
    Write-Warning "$Version necesita '$($chosen.shell)', que no está instalado. PowerShell 7: winget install Microsoft.PowerShell"
    exit 1
}

if (Test-Path $settingsFile) {
    $backup = "$settingsFile.bak-" + (Get-Date -Format "yyyyMMdd-HHmmss")
    Copy-Item $settingsFile $backup
    Write-Host "Copia de seguridad: $backup"
}

$command = if ($chosen.shell -eq "pwsh") { "pwsh -NoProfile -File " } else { "powershell -NoProfile -ExecutionPolicy Bypass -File " }
$statusLine = [ordered]@{ type = "command"; command = $command + (ScriptPath $Version) }
if ($chosen.refresh) { $statusLine.refreshInterval = $chosen.refresh }
$settings | Add-Member -NotePropertyName statusLine -NotePropertyValue ([pscustomobject]$statusLine) -Force

[IO.File]::WriteAllText($settingsFile, ($settings | ConvertTo-Json -Depth 20), (New-Object Text.UTF8Encoding $false))
Write-Host "Status line: $Version ($($chosen.about)). Se verá tras la próxima respuesta de Claude Code."
