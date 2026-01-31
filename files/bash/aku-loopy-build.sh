#!/bin/bash
# Aku Loop v3 - Build Mode
# Usage: ./aku-loopy-build.sh [options]
# 
# Examples:
#   ./aku-loopy-build.sh                          # Build mode, unlimited iterations
#   ./aku-loopy-build.sh 20                        # Build mode, max 20 iterations
#   ./aku-loopy-build.sh --model sonnet            # Build mode with sonnet model
#   ./aku-loopy-build.sh --resume                  # Resume from last saved iteration
#
# Options:
#   --model <model>      Override default model (opus/sonnet/etc)
#   --cooldown <secs>    Delay between iterations (default: 0)
#   --resume             Resume from last saved iteration count
#   --log-dir <dir>      Directory for log files (default: ./logs)
#   --no-log             Disable logging to file

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# Configuration Defaults
# ═══════════════════════════════════════════════════════════════════════════════
MODE="build"
PROMPT_FILE="PROMPT_build.md"
MAX_ITERATIONS=0
MODEL="opus"
COOLDOWN=0
RESUME=false
LOG_DIR="./logs"
LOG_ENABLED=true
STATE_FILE=".aku_loop_state"

# ═══════════════════════════════════════════════════════════════════════════════
# Argument Parsing
# ═══════════════════════════════════════════════════════════════════════════════
while [[ $# -gt 0 ]]; do
    case $1 in
        --model)
            MODEL="$2"
            shift 2
            ;;
        --cooldown)
            COOLDOWN="$2"
            shift 2
            ;;
        --resume)
            RESUME=true
            shift
            ;;
        --log-dir)
            LOG_DIR="$2"
            shift 2
            ;;
        --no-log)
            LOG_ENABLED=false
            shift
            ;;
        [0-9]*)
            MAX_ITERATIONS="$1"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# ═══════════════════════════════════════════════════════════════════════════════
# Pre-flight Checks
# ═══════════════════════════════════════════════════════════════════════════════
preflight_checks() {
    local errors=0
    
    echo "Running pre-flight checks (BUILD Mode)..."
    
    # Check prompt file exists
    if [ ! -f "$PROMPT_FILE" ]; then
        echo "  ✗ Prompt file not found: $PROMPT_FILE"
        errors=$((errors + 1))
    else
        echo "  ✓ Prompt file: $PROMPT_FILE"
    fi
    
    # Check specs directory exists and has files
    if [ ! -d "specs" ]; then
        echo "  ✗ specs/ directory not found"
        errors=$((errors + 1))
    elif [ -z "$(ls -A specs/ 2>/dev/null | grep -E '\.md$')" ]; then
        echo "  ⚠ specs/ directory is empty (no .md files)"
        echo "    Create spec files before running the loop."
        errors=$((errors + 1))
    else
        local spec_count=$(ls specs/*.md 2>/dev/null | wc -l)
        echo "  ✓ specs/ directory: $spec_count spec file(s) found"
    fi
    
    # Check AGENTS.md exists
    if [ ! -f "AGENTS.md" ]; then
        echo "  ✗ AGENTS.md not found"
        errors=$((errors + 1))
    else
        echo "  ✓ AGENTS.md present"
    fi
    
    # Check claude CLI is available
    if ! command -v claude &> /dev/null; then
        echo "  ✗ claude CLI not found in PATH"
        errors=$((errors + 1))
    else
        echo "  ✓ claude CLI available"
    fi
    
    # Check src directory (warning only)
    if [ ! -d "src" ]; then
        echo "  ⚠ src/ directory not found (will be created during build)"
    else
        echo "  ✓ src/ directory present"
    fi
    
    if [ $errors -gt 0 ]; then
        echo ""
        echo "Pre-flight checks failed with $errors error(s). Aborting."
        exit 1
    fi
    
    echo "Pre-flight checks passed."
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# State Management (Resume Capability)
# ═══════════════════════════════════════════════════════════════════════════════
save_state() {
    local iteration=$1
    echo "ITERATION=$iteration" > "$STATE_FILE"
    echo "MODE=$MODE" >> "$STATE_FILE"
    echo "TIMESTAMP=$(date -Iseconds)" >> "$STATE_FILE"
}

load_state() {
    if [ -f "$STATE_FILE" ]; then
        source "$STATE_FILE"
        echo "Resuming from iteration $ITERATION"
        return $ITERATION
    fi
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# Logging
# ═══════════════════════════════════════════════════════════════════════════════
setup_logging() {
    if [ "$LOG_ENABLED" = true ]; then
        mkdir -p "$LOG_DIR"
        LOG_FILE="$LOG_DIR/aku_loop_build_$(date +%Y%m%d_%H%M%S).jsonl"
        echo "Logging to: $LOG_FILE"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Iteration Summary Parser
# ═══════════════════════════════════════════════════════════════════════════════
parse_iteration_summary() {
    local log_file=$1
    
    if [ ! -f "$log_file" ]; then
        return
    fi
    
    echo ""
    echo "┌─────────────────────────────────────────────────────────────────────┐"
    echo "│ Iteration Summary                                                   │"
    echo "├─────────────────────────────────────────────────────────────────────┤"
    
    # Count tool calls by type
    local file_edits=$(grep -c '"name":"Edit"' "$log_file" 2>/dev/null || echo "0")
    local file_creates=$(grep -c '"name":"Write"' "$log_file" 2>/dev/null || echo "0")
    local file_reads=$(grep -c '"name":"Read"' "$log_file" 2>/dev/null || echo "0")
    local bash_calls=$(grep -c '"name":"Bash"' "$log_file" 2>/dev/null || echo "0")
    local subagent_calls=$(grep -c '"name":"Task"' "$log_file" 2>/dev/null || echo "0")
    
    printf "│ Files read:     %-5s  Files created: %-5s  Files edited: %-5s │\n" "$file_reads" "$file_creates" "$file_edits"
    printf "│ Bash commands:  %-5s  Subagents:     %-5s                       │\n" "$bash_calls" "$subagent_calls"
    
    # Check for errors in output
    local errors=$(grep -c '"is_error":true' "$log_file" 2>/dev/null || echo "0")
    if [ "$errors" -gt 0 ]; then
        printf "│ ⚠ Errors encountered: %-5s                                       │\n" "$errors"
    fi
    
    echo "└─────────────────────────────────────────────────────────────────────┘"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Completion Detection
# ═══════════════════════════════════════════════════════════════════════════════
plan_has_uncompleted_tasks() {
    local plan_file="IMPLEMENTATION_PLAN.md"
    
    if [ ! -f "$plan_file" ]; then
        # No plan file means we can't detect completion
        return 0  # true in bash (has work)
    fi
    
    # Look for uncompleted task markers
    # - [ ] unchecked checkbox
    # - TODO, PENDING, NOT STARTED, IN PROGRESS
    if grep -qiE '\- \[ \]|Status:.*?(TODO|PENDING|NOT STARTED|IN PROGRESS|INCOMPLETE)|^\s*-\s*(TODO|PENDING)\s*:' "$plan_file" 2>/dev/null; then
        return 0  # true - has uncompleted tasks
    fi
    
    # Check if there are completed markers (plan has content)
    if grep -qiE '\- \[[xX]\]|Status:.*?(DONE|COMPLETE|COMPLETED|FINISHED)|✅|✔|☑' "$plan_file" 2>/dev/null; then
        return 1  # false - all tasks completed
    fi
    
    # No markers found either way - assume work remains
    return 0
}

claude_reported_complete() {
    local log_file=$1
    
    if [ ! -f "$log_file" ]; then
        return 1  # false
    fi
    
    # Look for completion signals in Claude's output (case insensitive)
    if grep -qiE 'nothing to implement|no remaining tasks|all tasks.*(completed|done|finished)|implementation.*(is )?complete|project.*(is )?(complete|finished)|no more tasks|nothing left to (do|implement|build)|all items.*(completed|done|checked)' "$log_file" 2>/dev/null; then
        return 0  # true - Claude says complete
    fi
    
    return 1  # false
}

# ═══════════════════════════════════════════════════════════════════════════════
# Git Detection
# ═══════════════════════════════════════════════════════════════════════════════
GIT_REPO=$(git rev-parse --git-dir 2>/dev/null || echo "")
CURRENT_BRANCH=""
if [ -n "$GIT_REPO" ]; then
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Main Execution
# ═══════════════════════════════════════════════════════════════════════════════

# Run pre-flight checks
preflight_checks

# Setup logging
setup_logging

# Initialize or resume iteration counter
ITERATION=0
if [ "$RESUME" = true ]; then
    if [ -f "$STATE_FILE" ]; then
        source "$STATE_FILE"
        ITERATION=${ITERATION:-0}
        echo "Resuming from iteration $ITERATION"
    else
        echo "No state file found. Starting from iteration 0."
    fi
fi

# Display configuration
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Aku Loop v2 - BUILD MODE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Mode:      $MODE"
echo "Prompt:    $PROMPT_FILE"
echo "Model:     $MODEL"
if [ -n "$GIT_REPO" ]; then
    echo "Branch:    $CURRENT_BRANCH"
else
    echo "Branch:    (no git repo, skipping git operations)"
fi
[ $MAX_ITERATIONS -gt 0 ] && echo "Max:       $MAX_ITERATIONS iterations"
[ $COOLDOWN -gt 0 ] && echo "Cooldown:  ${COOLDOWN}s between iterations"
[ "$LOG_ENABLED" = true ] && echo "Log:       $LOG_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Main loop
while true; do
    # Check max iterations
    if [ $MAX_ITERATIONS -gt 0 ] && [ $ITERATION -ge $MAX_ITERATIONS ]; then
        echo "Reached max iterations: $MAX_ITERATIONS"
        break
    fi
    
    ITERATION=$((ITERATION + 1))
    echo ""
    echo "════════════════════════ LOOP $ITERATION ════════════════════════"
    echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    # Save state before running
    save_state $ITERATION
    
    # Prepare iteration log file
    if [ "$LOG_ENABLED" = true ]; then
        ITER_LOG="$LOG_DIR/iteration_${ITERATION}_$(date +%H%M%S).jsonl"
    else
        ITER_LOG="/dev/null"
    fi
    
    # Run Claude with selected prompt
    # Capture exit code without failing immediately
    set +e
    cat "$PROMPT_FILE" | claude -p \
        --dangerously-skip-permissions \
        --output-format=stream-json \
        --model "$MODEL" \
        --verbose 2>&1 | tee "$ITER_LOG"
    
    CLAUDE_EXIT_CODE=$?
    set -e
    
    # Handle exit codes
    if [ $CLAUDE_EXIT_CODE -ne 0 ]; then
        echo ""
        echo "⚠ Claude exited with code $CLAUDE_EXIT_CODE"
        
        # Exit code 1 is often a normal termination, but higher codes indicate issues
        if [ $CLAUDE_EXIT_CODE -gt 1 ]; then
            echo "Critical error detected. Stopping loop."
            echo "Check logs for details: $ITER_LOG"
            exit $CLAUDE_EXIT_CODE
        fi
    fi
    
    # Parse and display iteration summary
    if [ "$LOG_ENABLED" = true ] && [ -f "$ITER_LOG" ]; then
        parse_iteration_summary "$ITER_LOG"
        
        # Append to main log file
        cat "$ITER_LOG" >> "$LOG_FILE"
    fi
    
    # ═══════════════════════════════════════════════════════════════════════════════
    # Completion Detection - Exit gracefully when project is done
    # ═══════════════════════════════════════════════════════════════════════════════
    CLAUDE_SAYS_COMPLETE=false
    if [ -f "$ITER_LOG" ] && claude_reported_complete "$ITER_LOG"; then
        CLAUDE_SAYS_COMPLETE=true
    fi
    
    if [ "$CLAUDE_SAYS_COMPLETE" = true ]; then
        echo ""
        echo "════════════════════════════════════════════════════════════════════"
        echo "✅ BUILD COMPLETE - Claude reported no remaining tasks"
        echo "════════════════════════════════════════════════════════════════════"
        break
    fi
    
    if ! plan_has_uncompleted_tasks; then
        echo ""
        echo "════════════════════════════════════════════════════════════════════"
        echo "✅ BUILD COMPLETE - All tasks in IMPLEMENTATION_PLAN.md are done"
        echo "════════════════════════════════════════════════════════════════════"
        break
    fi
    
    # Push changes after each iteration (if in git repo)
    if [ -n "$GIT_REPO" ]; then
        echo ""
        echo "Pushing changes to $CURRENT_BRANCH..."
        git push origin "$CURRENT_BRANCH" 2>/dev/null || {
            echo "Failed to push. Creating remote branch..."
            git push -u origin "$CURRENT_BRANCH" || echo "Push failed (may need to pull first)"
        }
    fi
    
    # Cooldown between iterations
    if [ $COOLDOWN -gt 0 ] && [ $MAX_ITERATIONS -ne 1 ]; then
        echo ""
        echo "Cooldown: waiting ${COOLDOWN}s before next iteration..."
        sleep $COOLDOWN
    fi
    
    echo ""
    echo "Completed: $(date '+%Y-%m-%d %H:%M:%S')"
done

# Cleanup state file on successful completion
if [ -f "$STATE_FILE" ]; then
    rm "$STATE_FILE"
    echo "Loop completed. State file cleaned up."
fi

echo ""
echo "Aku Loop (Build) finished."
[ "$LOG_ENABLED" = true ] && echo "Full log available at: $LOG_FILE"
