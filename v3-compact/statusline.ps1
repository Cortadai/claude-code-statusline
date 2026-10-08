# Claude Code Statusline v3 - works in Windows PowerShell 5.1 and pwsh 7
# One row: model · effort | context bar | tokens | project | git | account - plan | 5h | 7d | cold cache
# 7d shows from $WeekThreshold %; warnings only when they matter (compact, 5h/7d pace, cold cache)
# Colors: Catppuccin Macchiato palette

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Context % from which the compact warning shows up
$CompactThreshold = 50
# 7d % from which it shows up (it always shows when the pace runs out before the reset)
$WeekThreshold = 50
# Nerd Font icons in front of each element ($false = plain text labels)
$UseIcons = $true

$ESC = [char]27
# Non-ASCII glyphs as code points so the file parses the same in PowerShell 5.1 and 7
$FULL = [string][char]0x2588; $EMPTY = [string][char]0x2591
$WARN = [string][char]0x26A0; $RESET = [string][char]0x21BB; $SNOW = [string][char]0x2744
$MIDDOT = [string][char]0x00B7

$colors = @{
    flamingo = "240;198;198"
    mauve    = "198;160;246"
    red      = "237;135;150"
    peach    = "245;169;127"
    yellow   = "238;212;159"
    green    = "166;218;149"
    teal     = "139;213;202"
    sky      = "145;215;227"
    sapphire = "125;196;228"
    lavender = "183;189;248"
    subtext1 = "184;192;224"
    overlay1 = "128;135;162"
    surface2 = "91;96;120"
}

function Color($text, $colorRgb) { "${ESC}[38;2;${colorRgb}m${text}${ESC}[0m" }

# Nerd Font Material Design glyphs (U+F0000 range; the older U+E000-F8FF ones do not render in Claude Code)
$icons = @{
    model = 0xF06A9; effort = 0xF029A; project = 0xF024B; git = 0xF062C; plan = 0xF0004; context = 0xF01BC
    five_hour = 0xF051F; seven_day = 0xF00ED; reset = 0xF0450; cold = 0xF0717; alert = 0xF0026
}
# Icon plus a space, or the text label used when icons are off
function Icon($name, $fallback = "") { if ($UseIcons) { [char]::ConvertFromUtf32($icons[$name]) + " " } else { $fallback } }
# A warning sign on its own
function Alert { (Icon alert $WARN).Trim() }

function LevelColor([double]$p) {
    if ($p -lt 25) { $colors.green } elseif ($p -lt 50) { $colors.teal } elseif ($p -lt 75) { $colors.yellow }
    elseif ($p -lt 90) { $colors.peach } else { $colors.red }
}

# 10-cell bar
function Bar([double]$used) {
    $filled = [int][math]::Min(10, [math]::Floor($used / 10))
    "[" + (Color ($FULL * $filled) (LevelColor $used)) + (Color ($EMPTY * (10 - $filled)) $colors.surface2) + "]"
}

# Where a rate-limit window lands by its reset if usage keeps the current pace.
# Early use counts as at least $settle seconds, so a busy first hour doesn't read as all day.
function Forecast($window, [int]$length, [int]$settle, [long]$now) {
    if ($null -eq $window.used_percentage -or $null -eq $window.resets_at) { return -1 }
    $elapsed = $now - ($window.resets_at - $length)
    if ($elapsed -le 0 -or $elapsed -ge $length) { return -1 }
    $rate = $window.used_percentage / [math]::Max($elapsed, $settle)
    $window.used_percentage + $rate * ($window.resets_at - $now)
}

function Duration([double]$seconds) {
    if ($seconds -ge 3600) { "{0}h{1:D2}" -f [int][math]::Floor($seconds / 3600), [int][math]::Floor(($seconds % 3600) / 60) }
    else { "{0}m" -f [int][math]::Ceiling($seconds / 60) }
}

$inputJson = [Console]::In.ReadToEnd()
$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$output = @()

try {
    $data = $inputJson | ConvertFrom-Json

    # Model, without the "(1M context)" suffix, and effort
    $modelName = $data.model.display_name
    if (-not $modelName) { $modelName = "Claude" }
    $modelName = ($modelName -replace '\s*\([^)]*context\)', '').Trim()
    $model = Color ((Icon model) + $modelName) $colors.mauve
    if ($data.effort.level) { $model += (Color " $MIDDOT " $colors.overlay1) + (Color ((Icon effort) + $data.effort.level) $colors.lavender) }
    $output += $model

    # Context: bar, percentage, tokens (+ warning from $CompactThreshold)
    $contextSize = $data.context_window.context_window_size
    $u = $data.context_window.current_usage
    $currentTokens = 0
    if ($u) { $currentTokens = [long]$u.input_tokens + [long]$u.cache_creation_input_tokens + [long]$u.cache_read_input_tokens }
    $percent = 0
    if ($null -ne $data.context_window.used_percentage) { $percent = [int][math]::Floor($data.context_window.used_percentage) }
    elseif ($contextSize -gt 0) { $percent = [int][math]::Floor($currentTokens * 100 / $contextSize) }
    $output += (Color (Icon context) $colors.subtext1) + (Bar $percent) + " " + (Color "${percent}%" (LevelColor $percent))
    $tokens = Color ("{0}k/{1}k" -f [math]::Round($currentTokens / 1000), [math]::Round($contextSize / 1000)) $colors.sapphire
    if ($percent -ge $CompactThreshold) { $tokens += " " + (Color (Alert) $colors.peach) }
    $output += $tokens

    # Project
    $projectDir = $data.workspace.project_dir
    if ($projectDir) { $output += Color ((Icon project) + (Split-Path -Leaf $projectDir)) $colors.sky }

    # Git branch (* = uncommitted changes)
    if ($projectDir -and (Test-Path (Join-Path $projectDir ".git\HEAD"))) {
        $head = Get-Content (Join-Path $projectDir ".git\HEAD") -Raw
        if ($head -match "ref: refs/heads/(.+)") {
            $branch = $(if ($UseIcons) { Color (Icon git) $colors.flamingo } else { Color "git:" $colors.overlay1 }) + (Color $matches[1].Trim() $colors.flamingo)
            if (git -C $projectDir status --porcelain 2>$null) { $branch += Color "*" $colors.yellow }
            $output += $branch
        }
    }

    # Account and plan; the plan's "5x" may sit in either rate-limit tier field
    $claudeJsonPath = if ($env:CLAUDE_CONFIG_DIR) { Join-Path $env:CLAUDE_CONFIG_DIR ".claude.json" }
                      else { Join-Path $env:USERPROFILE ".claude.json" }
    $account = $null
    if (Test-Path $claudeJsonPath) {
        try { $account = (Get-Content $claudeJsonPath -Raw | ConvertFrom-Json).oauthAccount } catch {}
    }
    if ($account) {
        $plan = ($account.organizationType -replace '^claude_', '')
        if (-not $plan) { $plan = "free" }
        if ("$($account.userRateLimitTier) $($account.organizationRateLimitTier)" -match 'max_(\d+x)') { $plan += " $($matches[1])" }
        $isOrg = $account.organizationType -match 'team|enterprise'
        $owner = if ($isOrg -and $account.organizationName) { $account.organizationName.ToLower() } else { "personal" }
        $output += (Color ((Icon plan) + $owner) $colors.teal) + (Color " - " $colors.overlay1) + (Color $plan $colors.green)
    } else {
        $output += Color "api key / no login" $colors.overlay1
    }

    # Rate limits (only after the first response); warning + reset time when the pace reaches 100% first
    $limits = @(
        @{ name = "5h"; icon = "five_hour"; w = $data.rate_limits.five_hour; len = 18000;  settle = 1800 }
        @{ name = "7d"; icon = "seven_day"; w = $data.rate_limits.seven_day; len = 604800; settle = 86400 }
    )
    foreach ($l in $limits) {
        if ($null -eq $l.w -or $null -eq $l.w.used_percentage) { continue }
        $p = [int][math]::Round($l.w.used_percentage)
        $atRisk = (Forecast $l.w $l.len $l.settle $now) -ge 100
        if ($l.name -eq "7d" -and $p -lt $WeekThreshold -and -not $atRisk) { continue }

        $text = (Color ((Icon $l.icon) + "$($l.name) ") $colors.subtext1) + (Color "${p}%" (LevelColor $p))
        if ($atRisk) {
            $text += " " + (Color (Alert) $colors.peach)
            if ($l.w.resets_at -gt $now) {
                $when = if ($l.name -eq "5h") { Duration ($l.w.resets_at - $now) }
                        else {
                            $at = [DateTimeOffset]::FromUnixTimeSeconds($l.w.resets_at).LocalDateTime
                            $days = "dom", "lun", "mar", "mi$([char]0x00E9)", "jue", "vie", "s$([char]0x00E1)b"
                            "{0} {1:HH:mm}" -f $days[[int]$at.DayOfWeek], $at
                        }
                $text += " " + (Color ((Icon reset "$RESET ") + $when) $colors.subtext1)
            }
        }
        $output += $text
    }

    # Prompt cache: only when cold (the next message re-reads the whole context)
    $pc = $data.prompt_cache
    if ($pc -and $pc.caching_observed) {
        $left = if ($pc.warm -and $pc.expires_at) { $pc.expires_at - $now } else { 0 }
        if ($left -le 0) {
            $cold = Color ((Icon cold "$SNOW cache ") + "fr$([char]0x00ED)a") $colors.yellow
            if ($pc.recache_tokens_if_cold) { $cold += Color (" (relee {0}k)" -f [math]::Round($pc.recache_tokens_if_cold / 1000)) $colors.subtext1 }
            $output += $cold
        }
    }
} catch {
    $output = @((Color "Claude" $colors.mauve), (Color (Split-Path -Leaf (Get-Location)) $colors.sky))
}

Write-Output ($output -join (Color " | " $colors.overlay1))
