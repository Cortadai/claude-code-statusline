# Claude Code Statusline v2 (PowerShell 7)
# Line 1: model · effort | project | git | plan | cost · duration · lines changed
# Line 2: context bar (+ /compact warning) | 5h limit (+ pace) | 7d limit (+ pace) | prompt cache
# Colors: Catppuccin Macchiato palette
# Needs pwsh and a Nerd Font; install with ..\switch.ps1 v2

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Context % from which to suggest /compact (personal rule: compact at 50%)
$CompactThreshold = 50
# Nerd Font icons in front of each element ($false = plain text labels)
$UseIcons = $true
# Draw a rounded box around both lines ($false = plain lines)
$UseBox = $true
# Box border as a left-to-right gradient through the palette accents ($false = single gray)
$RainbowBox = $true
# How much the rainbow fades into the terminal background: 0 = full color, 1 = invisible
$RainbowDim = 0.7
# Between the two rows inside the box: "dotted" (dim ┄ divider), "line" (─ divider in the border colors), "blank" (empty row) or "none"
$RowSeparator = "dotted"
# 5h and 7d as thin lines (━━──) so the context bar stays the only solid one ($false = solid bars like context)
$ThinLimitBars = $true

$ESC = [char]27
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
# Lighter tints of the bar colors, for the pace forecast cells
$projected = @{
    $colors.green  = "205;235;196"
    $colors.teal   = "192;233;227"
    $colors.yellow = "246;234;206"
    $colors.peach  = "250;206;182"
    $colors.red    = "245;190;198"
}

function Color($text, $rgb) { "${ESC}[38;2;${rgb}m${text}${ESC}[0m" }

# Nerd Font Material Design glyphs (U+F0000 range; the older U+E000-F8FF ones do not render in Claude Code)
$icons = @{
    model = 0xF06A9; effort = 0xF029A; project = 0xF024B; git = 0xF062C; plan = 0xF0004
    cost = 0xF01C1; duration = 0xF0150; lines = 0xF0992; context = 0xF01BC
    five_hour = 0xF051F; seven_day = 0xF00ED; reset = 0xF0450; cache = 0xF140B; cold = 0xF0717; alert = 0xF0026
}
# Icon plus a space, or the text label used when icons are off
function Icon($name, $fallback = "") { if ($UseIcons) { [char]::ConvertFromUtf32($icons[$name]) + " " } else { $fallback } }

function LevelColor([double]$p) {
    if ($p -lt 25) { $colors.green } elseif ($p -lt 50) { $colors.teal } elseif ($p -lt 75) { $colors.yellow }
    elseif ($p -lt 90) { $colors.peach } else { $colors.red }
}

# 10-cell bar: used cells, then projected cells (pace forecast), then empty; -Thin draws it as a line
function Bar([double]$used, [double]$landing = -1, [switch]$Thin) {
    $c = LevelColor $used
    $filled = [math]::Min(10, [math]::Ceiling($used / 10))
    $reach = $filled
    if ($landing -gt $used) { $reach = [math]::Max($filled, [math]::Min(10, [math]::Ceiling($landing / 10))) }
    $cellUsed, $cellAhead, $cellFree = if ($Thin) { "━", "━", "─" } else { "█", "▓", "░" }
    $bar = (Color ($cellUsed * $filled) $c)
    if ($reach -gt $filled) { $bar += Color ($cellAhead * ($reach - $filled)) $projected[$c] }
    $bar += Color ($cellFree * (10 - $reach)) $colors.surface2
    if ($Thin) { $bar } else { "[$bar]" }
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
    if ($seconds -ge 3600) { "{0}h{1:D2}" -f [math]::Floor($seconds / 3600), [int][math]::Floor(($seconds % 3600) / 60) }
    else { "{0}m" -f [math]::Ceiling($seconds / 60) }
}

# Account (organization name on Team/Enterprise, else "personal") and plan, from .claude.json's oauthAccount
function Account {
    $jsonFile = if ($env:CLAUDE_CONFIG_DIR) { Join-Path $env:CLAUDE_CONFIG_DIR ".claude.json" } else { Join-Path $env:USERPROFILE ".claude.json" }
    if (-not (Test-Path $jsonFile)) { return $null }
    try { $acct = (Get-Content $jsonFile -Raw | ConvertFrom-Json).oauthAccount } catch { return $null }
    if (-not $acct) { return $null }
    $plan = ("$($acct.organizationType)" -replace '^claude_', '')
    if (-not $plan) { $plan = "free" }
    # The "5x" may sit in either rate-limit tier field (user on Team, organization on personal Max)
    if ("$($acct.userRateLimitTier) $($acct.organizationRateLimitTier)" -match 'max_(\d+x)') { $plan += " $($matches[1])" }
    $isOrg = "$($acct.organizationType)" -match 'team|enterprise'
    @{ owner = $(if ($isOrg -and $acct.organizationName) { $acct.organizationName.ToLower() } else { "personal" }); plan = $plan }
}

$inputJson = [Console]::In.ReadToEnd()
$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$sep = Color " │ " $colors.overlay1
$dot = Color " · " $colors.overlay1
$line1 = @()
$line2 = @()

try {
    $data = $inputJson | ConvertFrom-Json

    # ── Line 1 ──────────────────────────────────────────────────────────────
    # Model, without the "(1M context)" suffix, and effort
    $model = if ($data.model.display_name) { $data.model.display_name } else { "Claude" }
    $model = ($model -replace '\s*\([^)]*context\)', '').Trim()
    $modelText = Color ((Icon model) + $model) $colors.mauve
    if ($data.effort.level) { $modelText += $dot + (Color ((Icon effort) + $data.effort.level) $colors.lavender) }
    $line1 += $modelText

    # Project
    $projectDir = $data.workspace.project_dir
    if ($projectDir) { $line1 += Color ((Icon project) + (Split-Path -Leaf $projectDir)) $colors.sky }

    # Git branch (* = uncommitted changes)
    if ($projectDir -and (Test-Path (Join-Path $projectDir ".git/HEAD"))) {
        $head = Get-Content (Join-Path $projectDir ".git/HEAD") -Raw
        if ($head -match "ref: refs/heads/(.+)") {
            $branch = $(if ($UseIcons) { Color (Icon git) $colors.flamingo } else { Color "git:" $colors.overlay1 }) + (Color $matches[1].Trim() $colors.flamingo)
            if (git -C $projectDir status --porcelain 2>$null) { $branch += Color "*" $colors.yellow }
            $line1 += $branch
        }
    }

    # Account and plan
    $account = Account
    if ($account) { $line1 += (Color ((Icon plan) + $account.owner) $colors.teal) + $dot + (Color $account.plan $colors.green) }
    else { $line1 += Color "api key / no login" $colors.overlay1 }

    # Session cost (API-price estimate), duration and lines changed
    $cost = @()
    if ($data.cost.total_cost_usd -gt 0) { $cost += Color ((Icon cost '$') + $data.cost.total_cost_usd.ToString("N2", [Globalization.CultureInfo]::InvariantCulture)) $colors.subtext1 }
    if ($data.cost.total_duration_ms -gt 0) { $cost += Color ((Icon duration) + (Duration ($data.cost.total_duration_ms / 1000))) $colors.subtext1 }
    if ($data.cost.total_lines_added -or $data.cost.total_lines_removed) {
        $cost += (Color (Icon lines) $colors.subtext1) + (Color "+$([int]$data.cost.total_lines_added)" $colors.green) + " " + (Color "−$([int]$data.cost.total_lines_removed)" $colors.red)
    }
    if ($cost) { $line1 += $cost -join $dot }

    # ── Line 2 ──────────────────────────────────────────────────────────────
    # Context window
    $size = $data.context_window.context_window_size
    $u = $data.context_window.current_usage
    $tokens = 0
    if ($u) { $tokens = [long]$u.input_tokens + [long]$u.cache_creation_input_tokens + [long]$u.cache_read_input_tokens }
    $pct = if ($null -ne $data.context_window.used_percentage) { [math]::Floor($data.context_window.used_percentage) }
           elseif ($size -gt 0) { [math]::Floor($tokens * 100 / $size) } else { 0 }
    if ($size -gt 0) {
        $ctx = (Color (Icon context "ctx ") $colors.subtext1) + (Bar $pct) + " " + (Color "$pct%" (LevelColor $pct)) + " " +
               (Color ("{0}k/{1}k" -f [math]::Round($tokens / 1000), [math]::Round($size / 1000)) $colors.sapphire)
        if ($pct -ge $CompactThreshold) { $ctx += " " + (Color ((Icon alert "⚠ ") + "/compact") $colors.peach) }
        $line2 += $ctx
    }

    # Rate limits (Pro/Max only) with pace forecast; a ⚠ when the pace runs out before the reset
    $limits = @(
        @{ name = "5h"; icon = "five_hour"; w = $data.rate_limits.five_hour; len = 18000;  settle = 1800 }
        @{ name = "7d"; icon = "seven_day"; w = $data.rate_limits.seven_day; len = 604800; settle = 86400 }
    )
    foreach ($l in $limits) {
        if ($null -eq $l.w -or $null -eq $l.w.used_percentage) { continue }
        $p = [math]::Round($l.w.used_percentage)
        $landing = Forecast $l.w $l.len $l.settle $now
        $text = (Color ((Icon $l.icon) + "$($l.name) ") $colors.subtext1) + (Bar $p $landing -Thin:$ThinLimitBars) + " " + (Color "$p%" (LevelColor $p))
        if ($l.w.resets_at -gt $now) {
            $left = $l.w.resets_at - $now
            $when = if ($l.name -eq "5h") { Duration $left }
                    else { [DateTimeOffset]::FromUnixTimeSeconds($l.w.resets_at).LocalDateTime.ToString("ddd HH:mm", [Globalization.CultureInfo]"es-ES") }
            $text += " " + (Color ((Icon reset "↻ ") + $when) $colors.subtext1)
        }
        if ($landing -ge 100) { $text += " " + (Color (Icon alert "⚠").Trim() $colors.peach) }
        $line2 += $text
    }

    # Prompt cache: time left before it goes cold (then the next message re-reads the whole context)
    $pc = $data.prompt_cache
    if ($pc -and $pc.caching_observed) {
        $left = if ($pc.warm -and $pc.expires_at) { $pc.expires_at - $now } else { 0 }
        if ($left -gt 0) {
            $c = if ($left -lt 300) { $colors.yellow } else { $colors.green }
            $line2 += $(if ($UseIcons) { Color (Icon cache) $c } else { Color "cache " $colors.subtext1 }) + (Color (Duration $left) $c)
        } else {
            $cold = Color ((Icon cold "cache ❄ ") + "fría") $colors.yellow
            if ($pc.recache_tokens_if_cold) { $cold += Color (" (relee {0}k)" -f [math]::Round($pc.recache_tokens_if_cold / 1000)) $colors.subtext1 }
            $line2 += $cold
        }
    }
} catch {
    $line1 = @((Color "Claude" $colors.mauve), (Color (Split-Path -Leaf (Get-Location)) $colors.sky))
    $line2 = @()
}

$rows = @($line1 -join $sep)
if ($line2) { $rows += $line2 -join $sep }

if (-not $UseBox) {
    $rows | ForEach-Object { Write-Output $_ }
    return
}

# On-screen width: ANSI codes take no columns, and a Nerd Font icon (a surrogate pair) takes one
function VisibleWidth($text) {
    [Globalization.StringInfo]::new(($text -replace "$ESC\[[0-9;]*m", "")).LengthInTextElements
}

# Pad every row to the widest one so the right border lines up
$width = ($rows | ForEach-Object { VisibleWidth $_ } | Measure-Object -Maximum).Maximum
$boxWidth = $width + 4

# One border color per column: Catppuccin Macchiato accents in hue order, blended between stops
$stops = @("237;135;150", "245;169;127", "238;212;159", "166;218;149", "139;213;202",
           "145;215;227", "125;196;228", "138;173;244", "183;189;248", "198;160;246", "245;189;230")
$borderColors = foreach ($i in 0..($boxWidth - 1)) {
    if (-not $RainbowBox) { $colors.overlay1; continue }
    $x = $i / ($boxWidth - 1) * ($stops.Count - 1)
    $k = [math]::Min([math]::Floor($x), $stops.Count - 2)
    $t = $x - $k
    $a = $stops[$k] -split ";"; $b = $stops[$k + 1] -split ";"
    $base = 36, 39, 58  # Catppuccin Macchiato background
    (0..2 | ForEach-Object {
        $c = [int]$a[$_] + ([int]$b[$_] - [int]$a[$_]) * $t
        [math]::Round($c + ($base[$_] - $c) * $RainbowDim)
    }) -join ";"
}

function Rule($left, $right) {
    -join (0..($boxWidth - 1) | ForEach-Object {
        $ch = if ($_ -eq 0) { $left } elseif ($_ -eq $boxWidth - 1) { $right } else { "─" }
        Color $ch $borderColors[$_]
    })
}

# Row separator; the side joints keep the border colors so the box stays continuous
$separatorRow = switch ($RowSeparator) {
    "dotted" { (Color "├" $borderColors[0]) + (Color ("┄" * ($boxWidth - 2)) $colors.surface2) + (Color "┤" $borderColors[-1]) }
    "line"   { Rule "├" "┤" }
    "blank"  { (Color "│" $borderColors[0]) + (" " * ($boxWidth - 2)) + (Color "│" $borderColors[-1]) }
    default  { $null }
}

Write-Output (Rule "╭" "╮")
for ($r = 0; $r -lt $rows.Count; $r++) {
    if ($r -gt 0 -and $separatorRow) { Write-Output $separatorRow }
    $row = $rows[$r]
    Write-Output ((Color "│" $borderColors[0]) + " " + $row + (" " * ($width - (VisibleWidth $row))) + " " + (Color "│" $borderColors[-1]))
}
Write-Output (Rule "╰" "╯")
