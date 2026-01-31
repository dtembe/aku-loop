# Aku Loop v2 - Build Mode
# Usage: .\aku-loop-build.ps1 [options]
#
# Examples:
#   .\aku-loop-build.ps1                        # Build mode, unlimited iterations
#   .\aku-loop-build.ps1 -MaxIterations 20      # Build mode, max 20 iterations
#   .\aku-loop-build.ps1 -Model sonnet          # Build mode with sonnet model
#   .\aku-loop-build.ps1 -Resume                # Resume from last saved iteration
#
# Options:
#   -MaxIterations <n>   Maximum iterations (0 = unlimited)
#   -Model <model>       Override default model (opus/sonnet/etc)
#   -Cooldown <secs>     Delay between iterations (default: 0)
#   -Resume              Resume from last saved iteration count
#   -LogDir <dir>        Directory for log files (default: ./logs)
#   -NoLog               Disable logging to file

[CmdletBinding()]
param(
    [int]$MaxIterations = 0,
    [string]$Model = "opus",
    [int]$Cooldown = 0,
    [switch]$Resume,
    [string]$LogDir = "./logs",
    [switch]$NoLog
)

$ErrorActionPreference = "Stop"

# ═══════════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════════
$StateFile = ".aku_loop_state"

$Mode = "build"
$PromptFile = "PROMPT_build.md"

$LogEnabled = -not $NoLog

# ═══════════════════════════════════════════════════════════════════════════════
# Pre-flight Checks
# ═══════════════════════════════════════════════════════════════════════════════
function Invoke-PreflightChecks {
    $errors = 0
    
    Write-Host "Running pre-flight checks (BUILD Mode)..." -ForegroundColor Cyan
    
    # Check prompt file exists
    if (-not (Test-Path $PromptFile)) {
        Write-Host "  ✗ Prompt file not found: $PromptFile" -ForegroundColor Red
        $errors++
    } else {
        Write-Host "  ✓ Prompt file: $PromptFile" -ForegroundColor Green
    }
    
    # Check specs directory exists and has files
    if (-not (Test-Path "specs")) {
        Write-Host "  ✗ specs/ directory not found" -ForegroundColor Red
        $errors++
    } else {
        $specFiles = Get-ChildItem -Path "specs" -Filter "*.md" -ErrorAction SilentlyContinue
        if ($null -eq $specFiles -or $specFiles.Count -eq 0) {
            Write-Host "  ⚠ specs/ directory is empty (no .md files)" -ForegroundColor Yellow
            Write-Host "    Create spec files before running the loop." -ForegroundColor Yellow
            $errors++
        } else {
            Write-Host "  ✓ specs/ directory: $($specFiles.Count) spec file(s) found" -ForegroundColor Green
        }
    }
    
    # Check AGENTS.md exists
    if (-not (Test-Path "AGENTS.md")) {
        Write-Host "  ✗ AGENTS.md not found" -ForegroundColor Red
        $errors++
    } else {
        Write-Host "  ✓ AGENTS.md present" -ForegroundColor Green
    }
    
    # Check claude CLI is available
    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if ($null -eq $claudeCmd) {
        Write-Host "  ✗ claude CLI not found in PATH" -ForegroundColor Red
        $errors++
    } else {
        Write-Host "  ✓ claude CLI available" -ForegroundColor Green
    }
    
    # Check src directory (warning only)
    if (-not (Test-Path "src")) {
        Write-Host "  ⚠ src/ directory not found (will be created during build)" -ForegroundColor Yellow
    } else {
        Write-Host "  ✓ src/ directory present" -ForegroundColor Green
    }
    
    if ($errors -gt 0) {
        Write-Host ""
        Write-Host "Pre-flight checks failed with $errors error(s). Aborting." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Pre-flight checks passed." -ForegroundColor Green
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# State Management (Resume Capability)
# ═══════════════════════════════════════════════════════════════════════════════
function Save-LoopState {
    param([int]$Iteration)
    
    @{
        Iteration = $Iteration
        Mode = $Mode
        Timestamp = (Get-Date -Format "o")
    } | ConvertTo-Json | Set-Content -Path $StateFile
}

function Get-LoopState {
    if (Test-Path $StateFile) {
        $state = Get-Content -Path $StateFile -Raw | ConvertFrom-Json
        return $state.Iteration
    }
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# Logging
# ═══════════════════════════════════════════════════════════════════════════════
function Initialize-Logging {
    if ($LogEnabled) {
        if (-not (Test-Path $LogDir)) {
            New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
        }
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $script:LogFile = Join-Path $LogDir "aku_loop_build_$timestamp.jsonl"
        Write-Host "Logging to: $script:LogFile" -ForegroundColor Gray
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# Iteration Summary Parser
# ═══════════════════════════════════════════════════════════════════════════════
function Show-IterationSummary {
    param([string]$IterLogFile)
    
    if (-not (Test-Path $IterLogFile)) {
        return
    }
    
    $content = Get-Content -Path $IterLogFile -Raw
    
    # Count tool calls by type
    $fileEdits = ([regex]::Matches($content, '"name":"Edit"')).Count
    $fileCreates = ([regex]::Matches($content, '"name":"Write"')).Count
    $fileReads = ([regex]::Matches($content, '"name":"Read"')).Count
    $bashCalls = ([regex]::Matches($content, '"name":"Bash"')).Count
    $subagentCalls = ([regex]::Matches($content, '"name":"Task"')).Count
    $errors = ([regex]::Matches($content, '"is_error":true')).Count
    
    Write-Host ""
    Write-Host "┌─────────────────────────────────────────────────────────────────────┐"
    Write-Host "│ Iteration Summary                                                   │"
    Write-Host "├─────────────────────────────────────────────────────────────────────┤"
    Write-Host ("│ Files read:     {0,-5}  Files created: {1,-5}  Files edited: {2,-5} │" -f $fileReads, $fileCreates, $fileEdits)
    Write-Host ("│ Bash commands:  {0,-5}  Subagents:     {1,-5}                       │" -f $bashCalls, $subagentCalls)
    
    if ($errors -gt 0) {
        Write-Host ("│ ⚠ Errors encountered: {0,-5}                                       │" -f $errors) -ForegroundColor Yellow
    }
    
    Write-Host "└─────────────────────────────────────────────────────────────────────┘"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Completion Detection
# ═══════════════════════════════════════════════════════════════════════════════
function Test-PlanHasUncompletedTasks {
    $planFile = "IMPLEMENTATION_PLAN.md"
    
    if (-not (Test-Path $planFile)) {
        # No plan file means we can't detect completion
        return $true
    }
    
    $content = Get-Content -Path $planFile -Raw
    
    # Look for common uncompleted task markers:
    # - [ ] unchecked checkbox
    # - TODO, PENDING, NOT STARTED, IN PROGRESS (case insensitive)
    # - ❌, ⬜, 🔲 (uncompleted emoji markers)
    $uncompletedPatterns = @(
        '\- \[ \]',                          # Markdown unchecked checkbox
        '\*\*Status:\*?\*?\s*(TODO|PENDING|NOT STARTED|IN PROGRESS|INCOMPLETE)',
        'Status:\s*(TODO|PENDING|NOT STARTED|IN PROGRESS|INCOMPLETE)',
        '^\s*-\s*(TODO|PENDING)\s*:',
        '❌|⬜|🔲'
    )
    
    foreach ($pattern in $uncompletedPatterns) {
        if ($content -match $pattern) {
            return $true
        }
    }
    
    # Also check if there are NO completed markers at all (empty/new plan)
    $completedPatterns = @(
        '\- \[x\]',                          # Markdown checked checkbox
        '\- \[X\]',
        '\*\*Status:\*?\*?\s*(DONE|COMPLETE|COMPLETED|FINISHED)',
        '✅|✔|☑'
    )
    
    $hasAnyCompleted = $false
    foreach ($pattern in $completedPatterns) {
        if ($content -match $pattern) {
            $hasAnyCompleted = $true
            break
        }
    }
    
    # If we found no uncompleted AND found some completed, we're done
    # If we found no completed either, assume work remains
    return -not $hasAnyCompleted
}

function Test-ClaudeReportedComplete {
    param([string]$IterLogFile)
    
    if (-not (Test-Path $IterLogFile)) {
        return $false
    }
    
    $content = Get-Content -Path $IterLogFile -Raw
    
    # Look for completion signals in Claude's output
    $completionPhrases = @(
        'nothing to implement',
        'no remaining tasks',
        'all tasks (have been |are )?(completed|done|finished)',
        'implementation (is )?complete',
        'project (is )?(complete|finished)',
        'no more tasks',
        'nothing left to (do|implement|build)',
        'all items.*(completed|done|checked)'
    )
    
    foreach ($phrase in $completionPhrases) {
        if ($content -match $phrase) {
            return $true
        }
    }
    
    return $false
}

# ═══════════════════════════════════════════════════════════════════════════════
# Git Detection
# ═══════════════════════════════════════════════════════════════════════════════
$GitRepo = $null
try {
    $GitRepo = git rev-parse --git-dir 2>$null
} catch {
    # Not in a git repo
}

$CurrentBranch = ""
if ($GitRepo) {
    try {
        $CurrentBranch = git branch --show-current 2>$null
    } catch {
        # Branch detection failed
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# Main Execution
# ═══════════════════════════════════════════════════════════════════════════════

# Run pre-flight checks
Invoke-PreflightChecks

# Setup logging
Initialize-Logging

# Initialize or resume iteration counter
$Iteration = 0
if ($Resume) {
    if (Test-Path $StateFile) {
        $Iteration = Get-LoopState
        Write-Host "Resuming from iteration $Iteration" -ForegroundColor Cyan
    } else {
        Write-Host "No state file found. Starting from iteration 0." -ForegroundColor Yellow
    }
}

# Display configuration
$Separator = "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host $Separator
Write-Host "Aku Loop v2 - BUILD MODE" -ForegroundColor Cyan
Write-Host $Separator
Write-Host "Mode:      $Mode"
Write-Host "Prompt:    $PromptFile"
Write-Host "Model:     $Model"
if ($GitRepo) {
    Write-Host "Branch:    $CurrentBranch"
} else {
    Write-Host "Branch:    (no git repo, skipping git operations)" -ForegroundColor Yellow
}
if ($MaxIterations -gt 0) {
    Write-Host "Max:       $MaxIterations iterations"
}
if ($Cooldown -gt 0) {
    Write-Host "Cooldown:  ${Cooldown}s between iterations"
}
if ($LogEnabled) {
    Write-Host "Log:       $script:LogFile"
}
Write-Host $Separator
Write-Host ""

# Main loop
while ($true) {
    # Check max iterations
    if ($MaxIterations -gt 0 -and $Iteration -ge $MaxIterations) {
        Write-Host "Reached max iterations: $MaxIterations" -ForegroundColor Green
        break
    }
    
    $Iteration++
    Write-Host ""
    Write-Host "════════════════════════ LOOP $Iteration ════════════════════════" -ForegroundColor Cyan
    Write-Host "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host ""
    
    # Save state before running
    Save-LoopState -Iteration $Iteration
    
    # Prepare iteration log file
    if ($LogEnabled) {
        $IterLog = Join-Path $LogDir "iteration_${Iteration}_$(Get-Date -Format 'HHmmss').jsonl"
    } else {
        $IterLog = $null
    }
    
    # Run Claude with selected prompt
    $claudeArgs = @(
        "-p",
        "--dangerously-skip-permissions",
        "--output-format=stream-json",
        "--model", $Model,
        "--verbose"
    )
    
    try {
        if ($IterLog) {
            Get-Content $PromptFile | claude @claudeArgs 2>&1 | Tee-Object -FilePath $IterLog
        } else {
            Get-Content $PromptFile | claude @claudeArgs
        }
        $ClaudeExitCode = $LASTEXITCODE
    } catch {
        $ClaudeExitCode = 1
        Write-Host "Error running Claude: $_" -ForegroundColor Red
    }
    
    # Handle exit codes
    if ($ClaudeExitCode -ne 0) {
        Write-Host ""
        Write-Host "⚠ Claude exited with code $ClaudeExitCode" -ForegroundColor Yellow
        
        # Exit code 1 is often a normal termination, but higher codes indicate issues
        if ($ClaudeExitCode -gt 1) {
            Write-Host "Critical error detected. Stopping loop." -ForegroundColor Red
            if ($IterLog) {
                Write-Host "Check logs for details: $IterLog" -ForegroundColor Yellow
            }
            exit $ClaudeExitCode
        }
    }
    
    # Parse and display iteration summary
    if ($LogEnabled -and $IterLog -and (Test-Path $IterLog)) {
        Show-IterationSummary -IterLogFile $IterLog
        
        # Append to main log file
        Get-Content $IterLog | Add-Content -Path $script:LogFile
    }
    
    # ═══════════════════════════════════════════════════════════════════════════════
    # Completion Detection - Exit gracefully when project is done
    # ═══════════════════════════════════════════════════════════════════════════════
    $claudeSaysComplete = $false
    if ($IterLog -and (Test-Path $IterLog)) {
        $claudeSaysComplete = Test-ClaudeReportedComplete -IterLogFile $IterLog
    }
    
    $planHasWork = Test-PlanHasUncompletedTasks
    
    if ($claudeSaysComplete) {
        Write-Host ""
        Write-Host "════════════════════════════════════════════════════════════════════" -ForegroundColor Green
        Write-Host "✅ BUILD COMPLETE - Claude reported no remaining tasks" -ForegroundColor Green
        Write-Host "════════════════════════════════════════════════════════════════════" -ForegroundColor Green
        break
    }
    
    if (-not $planHasWork) {
        Write-Host ""
        Write-Host "════════════════════════════════════════════════════════════════════" -ForegroundColor Green
        Write-Host "✅ BUILD COMPLETE - All tasks in IMPLEMENTATION_PLAN.md are done" -ForegroundColor Green
        Write-Host "════════════════════════════════════════════════════════════════════" -ForegroundColor Green
        break
    }
    
    # Push changes after each iteration (if in git repo)
    if ($GitRepo) {
        Write-Host ""
        Write-Host "Pushing changes to $CurrentBranch..." -ForegroundColor Gray
        $pushResult = git push origin "$CurrentBranch" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to push. Creating remote branch..." -ForegroundColor Yellow
            git push -u origin "$CurrentBranch" 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Push failed (may need to pull first)" -ForegroundColor Yellow
            }
        }
    }
    
    # Cooldown between iterations
    if ($Cooldown -gt 0 -and $MaxIterations -ne 1) {
        Write-Host ""
        Write-Host "Cooldown: waiting ${Cooldown}s before next iteration..." -ForegroundColor Gray
        Start-Sleep -Seconds $Cooldown
    }
    
    Write-Host ""
    Write-Host "Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
}

# Cleanup state file on successful completion
if (Test-Path $StateFile) {
    Remove-Item $StateFile -Force
    Write-Host "Loop completed. State file cleaned up." -ForegroundColor Green
}

Write-Host ""
Write-Host "Aku Loop (Build) finished." -ForegroundColor Green
if ($LogEnabled) {
    Write-Host "Full log available at: $script:LogFile" -ForegroundColor Gray
}

