# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository implements **The Aku Loop** - a documentation-based development methodology (originally "The Ralph Method") that uses autonomous AI agents to build software through iterative loops. It is a meta-project: a framework and documentation repository rather than a traditional software application.

**Key Concept**: Three Phases, Two Prompts, One Loop
- **Phase 1**: Define Requirements (human + LLM conversation creates specs)
- **Phase 2**: Run Aku Loop in PLANNING mode (gap analysis, creates implementation plan)
- **Phase 3**: Run Aku Loop in BUILDING mode (implements from plan)

## Running The Aku Loop

Both script names are equivalent: `loop.sh` = `aku_loop.sh`, and `loop.ps1` = `aku_loop.ps1`.

### Bash/Linux/macOS

```bash
# Navigate to bash folder
cd files/bash

# Make script executable (first time only)
chmod +x loop.sh              # or: chmod +x aku_loop.sh

# Build mode - unlimited iterations
./loop.sh                      # or: ./aku_loop.sh

# Build mode - max 20 iterations
./loop.sh 20                   # or: ./aku_loop.sh 20

# Plan mode - unlimited iterations
./loop.sh plan                 # or: ./aku_loop.sh plan

# Plan mode - max 5 iterations
./loop.sh plan 5               # or: ./aku_loop.sh plan 5

# Enhanced features
./loop.sh --model sonnet            # Override model (or use ./aku_loop.sh)
./loop.sh --cooldown 30             # 30s delay between iterations
./loop.sh --resume                  # Resume from last saved state
./loop.sh --log-dir ./my-logs       # Custom log directory
./loop.sh --no-log                  # Disable file logging
```

**Script Features:**
- Pre-flight checks (validates specs/, AGENTS.md, claude CLI)
- Configurable model override (`--model`)
- Log file output to `./logs/` directory
- Iteration summary (files read/created/edited per iteration)
- Cooldown timer between iterations (`--cooldown`)
- Resume capability (`--resume` with `.aku_loop_state` file)
- Exit code handling (stops on critical failures)

### PowerShell/Windows

```powershell
# Navigate to pwsh folder
cd files\pwsh

# Build mode - unlimited iterations
.\loop.ps1                           # or: .\aku_loop.ps1

# Build mode - max 20 iterations
.\loop.ps1 -MaxIterations 20         # or: .\aku_loop.ps1 -MaxIterations 20

# Plan mode - unlimited iterations
.\loop.ps1 -Plan                     # or: .\aku_loop.ps1 -Plan

# Plan mode - max 5 iterations
.\loop.ps1 -Plan -MaxIterations 5    # or: .\aku_loop.ps1 -Plan -MaxIterations 5

# Enhanced features
.\loop.ps1 -Model sonnet                # Override model (or use .\aku_loop.ps1)
.\loop.ps1 -Cooldown 30                 # 30s delay between iterations
.\loop.ps1 -Resume                      # Resume from last state
.\loop.ps1 -LogDir ./my-logs            # Custom log directory
.\loop.ps1 -NoLog                       # Disable file logging
```

### Loop Script Flags

Both scripts use these Claude CLI flags:
- `-p`: Headless mode (reads prompt from stdin)
- `--dangerously-skip-permissions`: Auto-approve all tool calls (required for autonomous operation)
- `--output-format=stream-json`: Structured output for logging
- `--model opus`: Uses Opus for complex reasoning (task selection, prioritization)
- `--verbose`: Detailed execution logging

### Security Warning

The `--dangerously-skip-permissions` flag bypasses Claude's permission system entirely. Running without a sandbox exposes credentials, browser cookies, SSH keys, and access tokens. Always run in isolated environments with minimum viable access.

### Git-Optional Operation

Both `loop.sh`/`aku_loop.sh` and `loop.ps1`/`aku_loop.ps1` automatically detect if running inside a git repository:
- **In git repo**: Normal behavior with commits and pushes after each iteration
- **No git repo**: Skips git operations, loop continues without version control

This allows experimentation and learning without requiring git initialization.

## High-Level Architecture

### The Three Phases

```
Phase 1: Define Requirements
    Human + LLM conversation
    ↓
    specs/*.md created (one per topic of concern)

Phase 2: PLANNING Mode
    Aku Loop studies specs/* and src/*
    ↓
    IMPLEMENTATION_PLAN.md created (prioritized task list)

Phase 3: BUILDING Mode
    Aku Loop picks tasks from plan
    ↓
    Implement → Test → Commit → Push → Loop
```

### Loop Mechanics

Each loop iteration follows a deterministic lifecycle:

**PLANNING mode:**
1. Study `specs/*` with parallel subagents
2. Study existing `src/*` code
3. Compare specs vs code (gap analysis)
4. Create/update `IMPLEMENTATION_PLAN.md`
5. No implementation

**BUILDING mode:**
1. Orient - study `specs/*` (requirements)
2. Read plan - study `IMPLEMENTATION_PLAN.md`
3. Select - pick the most important task
4. Investigate - search `src/*` ("don't assume not implemented")
5. Implement - N parallel subagents for file operations
6. Validate - 1 subagent for build/tests (backpressure)
7. Update `IMPLEMENTATION_PLAN.md` - mark task done, note discoveries
8. Update `AGENTS.md` - if operational learnings
9. Commit and push (if in git repo)
10. Loop ends → context cleared → next iteration starts fresh

### Repository Structure

```
Aku-Loop/
├── README.md                        # Complete Aku Loop documentation
├── CLAUDE.md                        # This file - guidance for Claude Code
├── _archive/                        # Original v1 scripts (archived)
│   ├── loop_v1.sh
│   └── loop_v1.ps1
├── files/
│   ├── bash/                        # Bash/Linux/macOS loop implementation
│   │   ├── loop.sh                  # Aku Loop orchestration script
│   │   ├── aku_loop.sh             # Same as loop.sh
│   │   ├── setup_git_repo.sh        # Helper: Create git repo + GitHub remote
│   │   ├── PROMPT_build.md          # BUILDING mode instructions
│   │   ├── PROMPT_plan.md           # PLANNING mode instructions
│   │   ├── AGENTS.md                # Operational guide (build/test commands)
│   │   └── IMPLEMENTATION_PLAN.md   # Prioritized task list (generated)
│   └── pwsh/                        # PowerShell/Windows loop implementation
│       ├── loop.ps1                 # Aku Loop orchestration script
│       ├── aku_loop.ps1            # Same as loop.ps1
│       ├── setup_git_repo.ps1       # Helper: Create git repo + GitHub remote
│       ├── PROMPT_build.md          # BUILDING mode instructions
│       ├── PROMPT_plan.md           # PLANNING mode instructions
│       ├── AGENTS.md                # Operational guide (build/test commands)
│       └── IMPLEMENTATION_PLAN.md   # Prioritized task list (generated)

# Project where Aku Loop is applied (separate repo):
project-root/
├── IMPLEMENTATION_PLAN.md           # Copied from Aku-Loop files/
├── AGENTS.md                        # Copied from Aku-Loop files/
├── PROMPT_build.md                  # Copied from Aku-Loop files/
├── PROMPT_plan.md                   # Copied from Aku-Loop files/
├── specs/                           # Requirement specs (one per JTD topic)
│   ├── [jtd-topic-a].md
│   └── [jtd-topic-b].md
└── src/                             # Application source code
    └── lib/                         # Shared utilities (standard library)
```

**Usage Pattern**: Copy the relevant files from `files/bash/` or `files/pwsh/` to your project root, then run the loop script from there.

## Key Concepts

### Topic Scope Test

A "topic of concern" should be describable in one sentence without "and":
- ✓ "The color extraction system analyzes images to identify dominant colors"
- ✗ "The user system handles authentication, profiles, and billing" → 3 topics

### Context Is Everything

- Main agent acts as scheduler, spawns subagents for expensive work
- Each subagent gets ~156kb that's garbage collected
- Prefer Markdown over JSON for better token efficiency
- Single task per loop = 100% smart zone context utilization

### Steering Aku Loop: Upstream and Downstream

**Upstream** (deterministic setup):
- Every loop loads the same files: `PROMPT.md` + `AGENTS.md`
- Existing code shapes what gets generated
- Add utilities/patterns to steer toward correct implementations

**Downstream** (backpressure):
- Tests, typechecks, lints, builds reject invalid work
- `AGENTS.md` provides project-specific validation commands
- Prompt says "run tests" generically; `AGENTS.md` specifies actual commands

### Let Aku Loop Ralph

- The plan is disposable - regenerate when wrong/stale
- Aku Loop achieves eventual consistency through iteration
- Observe and course correct - tune like a guitar
- Add "signs" (prompts, code patterns, AGENTS.md entries) based on observed failures

### Critical Guardrails

The build prompt uses numbered guardrails (9s sequence) - higher numbers = more critical:
- "don't assume not implemented" - the Achilles' heel of the approach
- "single sources of truth, no migrations/adapters"
- "implement functionality completely" - no placeholders or stubs
- Keep `AGENTS.md` operational only - status belongs in `IMPLEMENTATION_PLAN.md`

## Prompt Templates

### PROMPT_plan.md

Used for gap analysis and plan generation. Key sections:
- Phase 0 (0a-0d): Orient - study specs, existing plan, src/lib
- Phase 1: Compare specs vs code, create/update prioritized task list
- IMPORTANT guardrails: "Plan only", "don't assume not implemented", "ULTIMATE GOAL" placeholder

### PROMPT_build.md

Used for implementation. Key sections:
- Phase 0 (0a-0c): Orient - study specs, plan, src location
- Phase 1-4: Implement, test, update plan, commit
- 999... guardrails: Critical invariants (higher number = more priority)

### AGENTS.md

Concise operational guide (~60 lines max):
- Build & Run commands
- Validation commands (tests, typecheck, lint)
- Operational notes (learnings about running the project)
- Codebase patterns

**Critical**: Keep AGENTS.md brief. Status updates and progress notes belong in `IMPLEMENTATION_PLAN.md`. A bloated AGENTS.md pollutes every future loop's context.

### IMPLEMENTATION_PLAN.md

- Generated by Aku Loop during PLANNING mode
- Updated during BUILDING mode (mark complete, add discoveries)
- No predefined template - let Aku Loop/LLM dictate format
- Acts as shared state between otherwise isolated loop executions
- Can be regenerated anytime - disposable

### specs/*

- Created during Phase 1 (Requirements Definition)
- One markdown file per topic of concern
- Source of truth for what should be built
- No predefined template - let Aku Loop/LLM dictate format

## Development Patterns

### Subagent Usage

- **Study/Read**: Up to 500 parallel Sonnet subagents for codebase exploration
- **Build/Test**: Only 1 subagent (controls backpressure)
- **Complex Reasoning**: Opus subagents for debugging, architectural decisions
- **Ultrathink**: Request for extended reasoning on Opus subagents

**Note**: "Sonnet" and "Opus" refer to model shortcuts configured in Claude Code settings. These can be remapped to any LLM family (e.g., GLM, GPT) via `ANTHROPIC_DEFAULT_SONNET_MODEL` and `ANTHROPIC_DEFAULT_OPUS_MODEL` environment variables in your Claude Code `settings.json`.

### Git Workflow

Each iteration creates one commit (if in git repo):
1. Tests must pass before commit (backpressure)
2. Update `IMPLEMENTATION_PLAN.md` with findings
3. `git add -A` then `git commit` with descriptive message
4. `git push` after each iteration
5. Create git tags when no build/test errors (0.0.0 → 0.0.1 → ...)

### When the Plan Goes Wrong

Regenerate the plan if:
- Aku Loop is going off track (implementing wrong things, duplicating work)
- Plan feels stale or doesn't match current state
- Too much clutter from completed items
- Significant spec changes made
- Confusion about what's actually done

Regeneration cost: one Planning loop. Cheap compared to Aku Loop going in circles.

## Extension Concepts

The README documents several optional enhancements:

- **AskUserQuestion for Planning**: Use Claude's interview tool to clarify requirements during Phase 1
- **Acceptance-Driven Backpressure**: Derive test requirements from acceptance criteria during planning
- **Non-Deterministic Backpressure**: LLM-as-judge tests for subjective criteria (tone, aesthetics)
- **aku-loop-Friendly Work Branches**: Scoped planning per branch for parallel work streams
- **JTD → Story Map → SLC Release**: Product-focused planning with Simple/Lovable/Complete releases

These are documented for reference but not required for core Aku Loop functionality.