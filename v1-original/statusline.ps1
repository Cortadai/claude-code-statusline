# Claude Code Statusline Script for PowerShell
# Elements: Model name | Progress bar | Percentage context used | Tokens | Project name | Git branch | Account - plan
# Colors: Catppuccin Macchiato palette

# Fix: Force UTF-8 encoding so Unicode/Nerd Font glyphs render correctly in Claude Code statusline
# Windows PowerShell defaults to CP437, which garbles Unicode characters before Claude Code receives them
# See: https://github.com/anthropics/claude-code/issues/22457
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# ESC character for ANSI codes
$ESC = [char]27

# Catppuccin Macchiato colors (RGB)
$colors = @{
    rosewater = "244;219;214"
    flamingo  = "240;198;198"
    pink      = "245;189;230"
    mauve     = "198;160;246"
    red       = "237;135;150"
    maroon    = "238;153;160"
    peach     = "245;169;127"
    yellow    = "238;212;159"
    green     = "166;218;149"
    teal      = "139;213;202"
    sky       = "145;215;227"
    sapphire  = "125;196;228"
    blue      = "138;173;244"
    lavender  = "183;189;248"
    text      = "202;211;245"
    subtext1  = "184;192;224"
    overlay1  = "128;135;162"
    surface2  = "91;96;120"
}

# Helper function to colorize text
function Color($text, $colorRgb) {
    return "${ESC}[38;2;${colorRgb}m${text}${ESC}[0m"
}

# Read JSON from stdin
$inputJson = [Console]::In.ReadToEnd()

$output = @()

try {
    $data = $inputJson | ConvertFrom-Json

    # 1. Model name (mauve/purple)
    $modelName = $data.model.display_name
    if (-not $modelName) { $modelName = "Claude" }
    $output += Color $modelName $colors.mauve

    # 2 & 3. Progress bar and Percentage context used
    $contextSize = $data.context_window.context_window_size
    $currentUsage = $data.context_window.current_usage

    $percent = 0
    $currentTokens = 0
    if ($null -ne $currentUsage -and $contextSize -gt 0) {
        if ($currentUsage.input_tokens) { $currentTokens += $currentUsage.input_tokens }
        if ($currentUsage.cache_creation_input_tokens) { $currentTokens += $currentUsage.cache_creation_input_tokens }
        if ($currentUsage.cache_read_input_tokens) { $currentTokens += $currentUsage.cache_read_input_tokens }
        $percent = [math]::Floor(($currentTokens * 100) / $contextSize)
    }

    # Progress bar color based on percentage
    $barColor = if ($percent -lt 25) { $colors.green }
                elseif ($percent -lt 50) { $colors.teal }
                elseif ($percent -lt 75) { $colors.yellow }
                elseif ($percent -lt 90) { $colors.peach }
                else { $colors.red }

    # Create progress bar (10 chars wide)
    $filled = [math]::Floor($percent / 10)
    $empty = 10 - $filled
    $filledBar = ([char]9608).ToString() * $filled
    $emptyBar = ([char]9617).ToString() * $empty
    $bar = (Color $filledBar $barColor) + (Color $emptyBar $colors.surface2)
    $percentText = Color "${percent}%" $barColor
    $output += "[$bar] $percentText"

    # 4. Tokens (current usage / context window size) - sapphire/blue
    $currentK = [math]::Round($currentTokens / 1000)
    $maxK = [math]::Round($contextSize / 1000)
    $output += Color "${currentK}k/${maxK}k" $colors.sapphire

    # 5. Project name (sky/cyan)
    $projectDir = $data.workspace.project_dir
    if ($projectDir) {
        $projectName = Split-Path -Leaf $projectDir
        $output += Color $projectName $colors.sky
    }

    # 6. Git branch
    if ($projectDir -and (Test-Path $projectDir)) {
        $gitDir = Join-Path $projectDir ".git"
        if (Test-Path $gitDir) {
            $headFile = Join-Path $gitDir "HEAD"
            if (Test-Path $headFile) {
                $headContent = Get-Content $headFile -Raw
                if ($headContent -match "ref: refs/heads/(.+)") {
                    $gitBranch = $matches[1].Trim()
                    $statusMarker = ""

                    $oldLocation = Get-Location
                    Set-Location $projectDir
                    try {
                        $statusOutput = git status --porcelain 2>$null
                        if ($statusOutput) {
                            $statusMarker = Color "*" $colors.yellow
                        }
                    } catch {}
                    Set-Location $oldLocation

                    $gitPrefix = Color "git:" $colors.overlay1
                    $gitBranchColored = Color $gitBranch $colors.flamingo
                    $output += "${gitPrefix}${gitBranchColored}${statusMarker}"
                }
            }
        }
    }

    # 7. Subscription plan
    # Read the logged-in account from .claude.json (honors CLAUDE_CONFIG_DIR for multi-account setups)
    $claudeJsonPath = if ($env:CLAUDE_CONFIG_DIR) { Join-Path $env:CLAUDE_CONFIG_DIR ".claude.json" }
                      else { Join-Path $env:USERPROFILE ".claude.json" }
    $account = $null
    if (Test-Path $claudeJsonPath) {
        try { $account = (Get-Content $claudeJsonPath -Raw | ConvertFrom-Json).oauthAccount } catch {}
    }

    if ($account) {
        # organizationType: claude_max / claude_pro / claude_team / claude_enterprise
        $plan = ($account.organizationType -replace '^claude_', '')
        if (-not $plan) { $plan = "free" }
        # The "5x" may sit in either rate-limit tier field (user on Team, organization on personal Max)
        if ("$($account.userRateLimitTier) $($account.organizationRateLimitTier)" -match 'max_(\d+x)') { $plan += " $($matches[1])" }

        $isOrg = $account.organizationType -match 'team|enterprise'
        $owner = if ($isOrg -and $account.organizationName) { $account.organizationName.ToLower() } else { "personal" }
        $ownerColor = if ($isOrg) { $colors.peach } else { $colors.teal }
        $planColor = if ($isOrg) { $colors.yellow } else { $colors.green }

        $planLabel = (Color $owner $ownerColor) + (Color " - " $colors.overlay1) + (Color $plan $planColor)
    } else {
        $planLabel = Color "api key / no login" $colors.overlay1
    }
    $output += $planLabel

} catch {
    $output += Color "Claude" $colors.mauve
    $output += "[----------] 0%"
    $output += Color (Split-Path -Leaf (Get-Location)) $colors.sky
}

# Output with styled separators
$separator = Color " | " $colors.overlay1
Write-Output ($output -join $separator)
