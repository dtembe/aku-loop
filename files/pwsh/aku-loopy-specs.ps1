# Aku Loop v2 - Specs Interview Mode (File Based)
# Usage: .\aku-loopy-specs.ps1 [options]
# 
# Interactive specification builder. Acts as a Product Manager to interview you 
# via the 'SPECS_INTERVIEW.md' file and generate specification files in specs/
#
# Options:
#   -Model <model>       Override default model (e.g., sonnet)
#   -Clear               Clear conversation history/file and start fresh
#   -LogDir <dir>        Directory for logs

[CmdletBinding()]
param(
    [string]$Model = "sonnet",   # Default to Sonnet for faster chat
    [switch]$Clear,
    [string]$LogDir = "./logs"
)

$ErrorActionPreference = "Stop"
$PromptFile = "PROMPT_specs_interview.md"
$InterviewFile = "SPECS_INTERVIEW.md"
$SpecsDir = "specs"
$HistoryFile = ".spec_interview_history.txt" # Legacy, will detect and remove if present

# ═══════════════════════════════════════════════════════════════════════════════
# Setup
# ═══════════════════════════════════════════════════════════════════════════════

# Ensure styles
$BotColor = "Cyan"
$UserColor = "Green"
$SystemColor = "Gray"
$ErrColor = "Red"

# Ensure specs dir exists
if (-not (Test-Path $SpecsDir)) {
    New-Item -ItemType Directory -Path $SpecsDir -Force | Out-Null
    Write-Host "Created $SpecsDir folder." -ForegroundColor $SystemColor
}

# Clean legacy history file
if (Test-Path $HistoryFile) {
    Remove-Item $HistoryFile -Force
}

# Clear interview file if requested
if ($Clear -and (Test-Path $InterviewFile)) {
    Remove-Item $InterviewFile -Force
    Write-Host "Cleared $InterviewFile." -ForegroundColor "Yellow"
}

# Initialize Interview File if missing
if (-not (Test-Path $InterviewFile)) {
    $initialContent = @"
# Aku Loop - Specs Interview
Use this file to discuss your project requirements. 
Respond to questions under the '## You' sections.

## Aku (Product Manager)
Hello! I am your Product Manager. What would you like to build today?

## You
[Write your answer here...]
"@
    Set-Content -Path $InterviewFile -Value $initialContent -Encoding UTF8
    Write-Host "Created new interview file: $InterviewFile" -ForegroundColor $UserColor
}

# ═══════════════════════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════════════════════

function Show-Header {
    Clear-Host
    Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor $BotColor
    Write-Host "║              Aku Loop - Specification Interviewer                    ║" -ForegroundColor $BotColor
    Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor $BotColor
    Write-Host "Mode: File-Based Chat ($InterviewFile)"
    Write-Host "1. Write your answers in $InterviewFile"
    Write-Host "2. Save the file"
    Write-Host "3. Press ENTER in this terminal to send reply"
    Write-Host "Type 'exit' to quit."
    Write-Host ""
}

function Parse-And-Write-Files {
    param([string]$Content)
    
    # Regex to find [[FILE: path]] ... [[END FILE]] blocks
    $pattern = '\[\[FILE:\s*(.+?)\]\]\s*`?`?`?(?:markdown)?\s*(.*?)\s*`?`?`?\s*\[\[END FILE\]\]'
    $matches = [regex]::Matches($Content, $pattern, 'Singleline')
    
    $filesWritten = 0
    
    foreach ($match in $matches) {
        if ($match.Success) {
            $filePath = $match.Groups[1].Value.Trim()
            $fileContent = $match.Groups[2].Value
            
            # Ensure dir exists
            $dir = Split-Path -Path $filePath -Parent
            if ($dir -and -not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
            
            # Write file
            $fileContent | Set-Content -Path $filePath -Encoding UTF8
            Write-Host "  ➜ Wrote: $filePath" -ForegroundColor "Green"
            $filesWritten++
        }
    }
    return $filesWritten
}

# ═══════════════════════════════════════════════════════════════════════════════
# Main Loop
# ═══════════════════════════════════════════════════════════════════════════════

Show-Header

while ($true) {
    # 1. Wait for User Input
    Write-Host "Waiting for you to update $InterviewFile... (Press ENTER to send, 'exit' to quit)" -ForegroundColor $SystemColor
    $userInput = Read-Host ">"
    
    if ($userInput -eq "exit" -or $userInput -eq "quit") { break }
    
    # 2. Read the full transcript
    if (-not (Test-Path $InterviewFile)) {
        Write-Host "Error: $InterviewFile not found!" -ForegroundColor $ErrColor
        continue
    }
    
    $transcript = Get-Content -Path $InterviewFile -Raw -Encoding UTF8
    $systemPrompt = Get-Content $PromptFile -Raw -Encoding UTF8
    
    $fullPrompt = "$systemPrompt`n`n--- TRANSCRIPT START ---`n$transcript`n--- TRANSCRIPT END ---`n`nASSISTANT (Aku):"
    
    Write-Host "Thinking..." -ForegroundColor $SystemColor -NoNewline
    
    # 3. Call Claude
    try {
        # Feed via stdin
        $response = $fullPrompt | claude -p --dangerously-skip-permissions --model $Model
        if ($LASTEXITCODE -ne 0) {
            throw "Claude exited with code $LASTEXITCODE"
        }
    } catch {
        Write-Host "`nError calling Claude: $_" -ForegroundColor $ErrColor
        continue
    }
    
    Write-Host "`r          " -NoNewline # Clear 'Thinking...'
    Write-Host "`rAku responded. Updating $InterviewFile..." -ForegroundColor $BotColor
    
    # 4. Append Response to File
    $formattedResponse = "`n`n## Aku (Product Manager)`n$response"
    Add-Content -Path $InterviewFile -Value $formattedResponse -Encoding UTF8
    
    # 5. Check for File Generation
    if ($response -match "\[\[FILE:") {
        Write-Host ""
        Write-Host "Extracting specifications..." -ForegroundColor $SystemColor
        $count = Parse-And-Write-Files -Content $response
        
        if ($count -gt 0) {
            Write-Host ""
            Write-Host "✅ Successfully generated $count spec files in /$SpecsDir." -ForegroundColor "Green"
            Write-Host "You can now run '.\aku-loopy-plan.ps1' to verify and plan." -ForegroundColor "Green"
            
            # Append final note
            Add-Content -Path $InterviewFile -Value "`n`n## System`nSpecs generated. Session Complete." -Encoding UTF8
            break
        }
    }
    
    # 6. Add next user placeholder
    Add-Content -Path $InterviewFile -Value "`n`n## You`n" -Encoding UTF8
}
