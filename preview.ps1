# Renders the status line versions against a few made-up sessions, to compare them.
# Run: .\preview.ps1   (optional: -Versions v1,v3)
param([string[]]$Versions = @("v1", "v2", "v3"))
# "-Versions v1,v3" arrives as one string when run with -File
$Versions = $Versions -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ }

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$scripts = @{
    v1 = @{ path = "v1-original\statusline.ps1"; shell = "powershell" }
    v2 = @{ path = "v2-box\statusline.ps1";      shell = "pwsh" }
    v3 = @{ path = "v3-compact\statusline.ps1";  shell = "powershell" }
}
$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
# A git repo, so the branch shows up in the scenarios that ask for it
$repo = Join-Path $env:TEMP "statusline-preview-repo"
if (-not (Test-Path (Join-Path $repo ".git"))) {
    New-Item -ItemType Directory -Force $repo | Out-Null
    git -C $repo init -q -b main 2>$null
    Set-Content (Join-Path $repo "cambios.txt") "sin commitear"
}

function Session($ctx, $fiveUsed, $fiveLeft, $weekUsed, $weekLeft, $cacheLeft, $dir) {
    $s = @{
        model          = @{ display_name = "Opus 5.5 (1M context)" }
        effort         = @{ level = "high" }
        workspace      = @{ project_dir = $dir }
        context_window = @{ context_window_size = 1000000; used_percentage = $ctx
                            current_usage = @{ input_tokens = 0; cache_creation_input_tokens = 0; cache_read_input_tokens = $ctx * 10000 } }
    }
    if ($null -ne $fiveUsed) {
        $s.rate_limits = @{ five_hour = @{ used_percentage = $fiveUsed; resets_at = $now + $fiveLeft }
                            seven_day = @{ used_percentage = $weekUsed; resets_at = $now + $weekLeft } }
        $s.prompt_cache = @{ caching_observed = $true; warm = ($cacheLeft -gt 0); expires_at = $now + $cacheLeft
                             recache_tokens_if_cold = $ctx * 10000 }
    }
    $s | ConvertTo-Json -Depth 5
}

$mods = "C:\Users\dcortaberria\Desktop\sandbox\mods"
$scenarios = [ordered]@{
    "1. Recien abierta (aun sin limites)"            = Session 6 $null 0 0 0 0 $mods
    "2. Dia normal"                                  = Session 18 23 7700 41 300000 3100 $mods
    "3. Repo git con cambios"                         = Session 32 40 9000 45 200000 200 $repo
    "4. Dia apretado (5h al ritmo de pasarse)"       = Session 55 82 6000 61 100000 2400 $mods
    "5. Vuelves del cafe (cache fria)"               = Session 38 30 12000 52 250000 0 $mods
}

foreach ($name in $scenarios.Keys) {
    Write-Host ""
    Write-Host $name -ForegroundColor DarkGray
    foreach ($v in $Versions) {
        $s = $scripts[$v]
        if (-not (Get-Command $s.shell -ErrorAction SilentlyContinue)) { Write-Host "  $v  (necesita $($s.shell))" -ForegroundColor DarkGray; continue }
        $out = @($scenarios[$name] | & $s.shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot $s.path))
        for ($i = 0; $i -lt $out.Count; $i++) {
            Write-Host -NoNewline $(if ($i -eq 0) { "  $v  " } else { "      " }) -ForegroundColor DarkGray
            Write-Host $out[$i]
        }
    }
}
Write-Host ""
