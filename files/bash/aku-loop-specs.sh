#!/bin/bash
# Aku Loop v2 - Specs Interview Mode (File Based)
# Usage: ./aku-loop-specs.sh [options]
# 
# Interactive specification builder. Acts as a Product Manager to interview you 
# via the 'SPECS_INTERVIEW.md' file and generate specification files in specs/
#
# Options:
#   --model <model>      Override default model (e.g., sonnet)
#   --clear              Clear conversation history/file and start fresh

set -euo pipefail

MODEL="sonnet"
CLEAR=false

PROMPT_FILE="PROMPT_specs_interview.md"
INTERVIEW_FILE="SPECS_INTERVIEW.md"
SPECS_DIR="specs"
HISTORY_FILE=".spec_interview_history.txt" # Legacy

# ═══════════════════════════════════════════════════════════════════════════════
# Argument Parsing
# ═══════════════════════════════════════════════════════════════════════════════
while [[ $# -gt 0 ]]; do
    case $1 in
        --model)
            MODEL="$2"
            shift 2
            ;;
        --clear)
            CLEAR=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# ═══════════════════════════════════════════════════════════════════════════════
# Setup
# ═══════════════════════════════════════════════════════════════════════════════
# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
GRAY='\033[0;90m'
RED='\033[0;31m'
NC='\033[0m' # No Color

mkdir -p "$SPECS_DIR"

# Clean legacy
if [ -f "$HISTORY_FILE" ]; then rm "$HISTORY_FILE"; fi

if [ "$CLEAR" = true ] && [ -f "$INTERVIEW_FILE" ]; then
    rm "$INTERVIEW_FILE"
    echo "Cleared $INTERVIEW_FILE."
fi

# Initialize File
if [ ! -f "$INTERVIEW_FILE" ]; then
    cat > "$INTERVIEW_FILE" <<EOF
# Aku Loop - Specs Interview
Use this file to discuss your project requirements. 
Respond to questions under the '## You' sections.

## Aku (Product Manager)
Hello! I am your Product Manager. What would you like to build today?

## You
[Write your answer here...]
EOF
    echo -e "${GREEN}Created new interview file: $INTERVIEW_FILE${NC}"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════════════════════

extract_files() {
    local input_text="$1"
    local in_file=false
    local current_file=""
    local file_count=0
    
    # We use a temp file to handle reading lines since variables in pipes are tricky in bash subshells
    # But here we can pipe the variable into while
    
    while IFS= read -r line; do
        if [[ "$line" =~ \[\[FILE:\ *([^]]+)\ *\]\] ]]; then
            current_file="${BASH_REMATCH[1]}"
            current_file=$(echo "$current_file" | xargs)
            # Ensure dir exists
            mkdir -p "$(dirname "$current_file")"
            # Truncate/create file
            : > "$current_file"
            in_file=true
            file_count=$((file_count + 1))
            echo "  ➜ Wrote: $current_file"
            continue
        fi
        
        if [[ "$line" =~ \[\[END\ FILE\]\] ]]; then
            in_file=false
            current_file=""
            continue
        fi
        
        if [ "$in_file" = true ] && [ -n "$current_file" ]; then
            # Check for markdown code fence start/end at beginning of file extraction to strip them?
            # The regex in pwsh was permissive. Here we just write line by line.
            # Ideally we strip leading ``` or ```markdown if they appear right after FILE tag
            # But simplistic approach: just write lines.
            echo "$line" >> "$current_file"
        fi
    done <<< "$input_text"
    
    echo "$file_count"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Main Loop
# ═══════════════════════════════════════════════════════════════════════════════

clear
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              Aku Loop - Specification Interviewer                    ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
echo "Mode: File-Based Chat ($INTERVIEW_FILE)"
echo "1. Write your answers in $INTERVIEW_FILE"
echo "2. Save the file"
echo "3. Press ENTER in this terminal to send reply"
echo "Type 'exit' to quit."
echo ""
while true; do
    # 1. Wait for User Input
    echo -e "${GRAY}Waiting for you to update $INTERVIEW_FILE... (Press ENTER to send, 'exit' to quit)${NC}"
    printf "> "
    IFS= read -r user_input

    if [[ "$user_input" == "exit" ]] || [[ "$user_input" == "quit" ]]; then
        break
    fi

    # 2. Read Transcript
    if [ ! -f "$INTERVIEW_FILE" ]; then
        echo -e "${RED}Error: $INTERVIEW_FILE not found!${NC}"
        continue
    fi

    if [ ! -f "$PROMPT_FILE" ]; then
        echo -e "${RED}Error: $PROMPT_FILE not found!${NC}"
        exit 1
    fi

    TRANSCRIPT=$(<"$INTERVIEW_FILE")
    SYSTEM_PROMPT=$(<"$PROMPT_FILE")
    FULL_PROMPT="${SYSTEM_PROMPT}\n\n--- TRANSCRIPT START ---\n${TRANSCRIPT}\n--- TRANSCRIPT END ---\n\nASSISTANT (Aku):"
    
    echo -e -n "${GRAY}Thinking...${NC}"
    
    # 3. Call Claude
    # We capture output to variable. 
    RESPONSE=$(echo -e "$FULL_PROMPT" | claude -p --dangerously-skip-permissions --model "$MODEL") || {
        echo -e "\n${RED}Error calling Claude${NC}"
        continue
    }
    
    echo -e "\r          \r${CYAN}Aku responded. Updating $INTERVIEW_FILE...${NC}"
    
    # 4. Append Response
    echo -e "\n\n## Aku (Product Manager)\n$RESPONSE" >> "$INTERVIEW_FILE"
    
    # 5. Check for Files
    if [[ "$RESPONSE" == *"[[FILE:"* ]]; then
        echo ""
        echo -e "${GRAY}Extracting specifications...${NC}"
        # We need to capture the echoed count, but extract_files also echoes "Wrote: ..." to stdout.
        # Let's adjust extract_files to print "WROTE:path" and "COUNT:n" to differentiate or return status.
        # Simpler: Just run it and grep the output if needed, or rely on side effects.
        # But we need the count to know if we should break.
        
        # Capture all output
        OUTPUT=$(extract_files "$RESPONSE")
        echo "$OUTPUT" | grep "➜ Wrote:" # Show the user what happened
        
        # Get the last line which is the count
        COUNT=$(echo "$OUTPUT" | tail -n 1)
        
        if [[ "$COUNT" -gt 0 ]]; then
            echo ""
            echo -e "${GREEN} check Successfully generated $COUNT spec files in /$SPECS_DIR.${NC}"
            echo -e "${GREEN}You can now run './aku-loop-plan.sh' to verify and plan.${NC}"
            
            echo -e "\n\n## System\nSpecs generated. Session Complete." >> "$INTERVIEW_FILE"
            break
        fi
    fi
    
    # 6. Add Placeholder
    echo -e "\n\n## You\n" >> "$INTERVIEW_FILE"
done

