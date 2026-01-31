# The Aku Loop

<img src="artifacts/Aku-icon.png" width="150" alt="Aku Logo" />

**The Aku Loop** is an implementation of [Geoffrey Huntley's Ralph Method](https://ghuntley.com/ralph/) - a documentation-based development methodology that uses autonomous AI agents to build software through iterative loops.

This repository provides both Bash and PowerShell implementations, with git-optional operation for maximum flexibility.

## Quick Start

### 1. Get the Tools

Clone the repository to get the scripts:

```bash
git clone https://github.com/dtembe/aku-loop.git
```

### 2. Initialize Your Project

Copy the scripts to *your* project root (not inside the Aku Loop folder):

**PowerShell (Windows)**
```powershell
# Copy scripts to your project
Copy-Item -Recurse .\aku-loop\files\pwsh\* C:\path\to\your-project\
cd C:\path\to\your-project\
```

**Bash (Linux/macOS)**
```bash
# Copy scripts to your project
cp -r ./aku-loop/files/bash/* /path/to/your-project/
cd /path/to/your-project/
chmod +x *.sh
```

### 3. Run the Loop

Now run the 3-stage process directly from your project root:

**PowerShell**
```powershell
# 1. SPECS Mode: Interactive interview to generate specs
.\aku-loop-specs.ps1

# 2. PLAN Mode: Analyze specs, create tasks
.\aku-loop-plan.ps1 -MaxIterations 1 # New project: 1 iteration is enough

# 3. BUILD Mode: Execute plan, write code
.\aku-loop-build.ps1
```

**Bash**
```bash
# 1. SPECS Mode
./aku-loop-specs.sh

# 2. PLAN Mode
./aku-loop-plan.sh 1                 # New project: 1 iteration is enough

# 3. BUILD Mode
./aku-loop-build.sh
```
```
Common options for all scripts:
- `--model` / `-Model` (e.g., `sonnet`)
- `--resume` / `-Resume`
- `--cooldown` / `-Cooldown`
```

---

## Table of Contents

- [Overview](#overview)
- [Workflow](#workflow)
- [Installation](#installation)
- [Repository Structure](#repository-structure)
- [Key Principles](#key-principles)
- [Loop Mechanics](#loop-mechanics)
- [Configuration](#configuration)

---

## Overview

The Ralph Method is a documentation-driven development process that leverages autonomous AI agents to iteratively build software. It breaks down high-level requirements into manageable tasks, allowing an LLM to plan, implement, test, and commit code in a structured loop.

This is **The Aku Loop** - a practical, working implementation you can run today on both Unix and Windows systems.

### What Makes This Implementation Different

| Feature | Description |
|---------|-------------|
| **Dedicated Modes** | Separate scripts for `plan` and `build` ensure clear intent and execution context |
| **Cross-Platform** | Bash for Unix/macOS, PowerShell for Windows |
| **Git-Optional** | Automatically detects git repos; skips version control if not present |
| **Model Agnostic** | Works with any LLM family (Claude, GPT, GLM) via Claude Code settings |
| **Ready to Use** | Copy files to any project and run |

---

## Workflow

### 🗘 Three Phases, Two Prompts, One Loop

This isn't just "a loop that codes." It's a funnel with 3 Phases, 2 Prompts, and 1 Loop.

#### Phase 1. Define Requirements (Interactive Interview)

Instead of writing markdown files manually, use the interactive Product Manager agent to define your project.

```powershell
# Windows
.\aku-loop-specs.ps1
```

```bash
# Linux/macOS
./aku-loop-specs.sh
```

**The Loop:**
1.  Agent initializes a conversation in `SPECS_INTERVIEW.md`.
2.  You write your answers in the file and save.
3.  Agent reads the file, asks clarifying questions, and effectively interviews you.
4.  Once requirements are clear, Agent automatically writes detailed files to the `specs/` directory using the `NN-jtd-topic.md` convention.

#### Phase 2. Planning


Run `aku-loop-plan` to analyze specs and generate the implementation plan.

- **Objective:** Generate/update `IMPLEMENTATION_PLAN.md`
- **Activity:** Gap analysis (specs vs code)
- **Output:** A prioritized TODO list—no implementation, no commits
- **Context:** `PROMPT_plan.md` + `specs/*` + existing code

**How many iterations?**

| Scenario | Recommended Iterations |
|----------|------------------------|
| **New/greenfield project** (empty `src/`) | 1 iteration |
| **Existing codebase** with partial implementation | 2-5 iterations |
| **Complex project** with many specs | 3-5 iterations |
| **Specs changed** after partial build | 1-2 iterations |

> **Tip:** For a brand new project, use `-MaxIterations 1`. The agent will generate a complete plan in one pass. Running more iterations just re-confirms the same plan. Save those cycles for Build mode where iterations produce actual code.

#### Phase 3. Building

Run `aku-loop-build` to execute the plan.

- **Objective:** Implement features, fix bugs, update plan
- **Activity:** Reads `IMPLEMENTATION_PLAN.md`, picks top task, implements, tests
- **Context:** `PROMPT_build.md` + `AGENTS.md` + `IMPLEMENTATION_PLAN.md`

**Auto-completion detection:** The build script automatically stops when:
- All tasks in `IMPLEMENTATION_PLAN.md` are marked complete (`[✓]`, `[x]`, `DONE`)
- Claude reports "nothing to implement" or similar completion phrases

This means you can run without `-MaxIterations` and trust it to stop when done.

**Why separate scripts?**
- Clarity: Clearly separates the "thinking" (Planning) from the "doing" (Building)
- Safety: Planning mode is read-only regarding code changes (it only writes the plan)
- Simplicity: Each script has a single focus and default configuration


**PLANNING mode loop lifecycle:**
1. Subagents study `specs/*` and existing `/src`
2. Compare specs against code (gap analysis)
3. Create/update `IMPLEMENTATION_PLAN.md` with prioritized tasks
4. No implementation

**BUILDING mode loop lifecycle:**
1. _Orient_ – subagents study `specs/*` (requirements)
2. _Read plan_ – study `IMPLEMENTATION_PLAN.md`
3. _Select_ – pick the most important task
4. _Investigate_ – subagents study relevant `/src` ("don't assume not implemented")
5. _Implement_ – N subagents for file operations
6. _Validate_ – 1 subagent for build/tests (backpressure)
7. _Update `IMPLEMENTATION_PLAN.md`_ – mark task done, note discoveries/bugs
8. _Update `AGENTS.md`_ – if operational learnings
9. _Commit_ (if in git repo)
10. _Loop ends_ → context cleared → next iteration starts fresh

#### Concepts

| Term                    | Definition                                                      |
| ----------------------- | --------------------------------------------------------------- |
| _Job To Do (JTD)_       | High-level user need or outcome                                 |
| _Topic of Concern_      | A distinct aspect/component within a JTD (Job To Do)            |
| _Spec_                  | Requirements doc for one topic of concern (`specs/NN-jtd-topic.md`) |
| _Task_                  | Unit of work derived from comparing specs to code               |
| _SPECS_INTERVIEW.md_    | The "chat room" file for requirements gathering                 |

**Relationships:**
- 1 JTD → multiple topics of concern
- 1 topic of concern → 1 spec
- 1 spec → multiple tasks (specs are larger than tasks)

**Topic Scope Test: "One Sentence Without 'And'"**

Can you describe the topic of concern in one sentence without conjoining unrelated capabilities?
- ✓ "The color extraction system analyzes images to identify dominant colors"
- ✗ "The user system handles authentication, profiles, and billing" → 3 topics

---

## Installation

### 1. Copy Files to Your Project

```bash
# For Bash/Linux/macOS
cp -r /path/to/Aku-Loop/files/bash/* /path/to/your/project/

# For PowerShell/Windows
Copy-Item -Recurse C:\path\to\Aku-Loop\files\pwsh\* C:\path\to\your\project\
```

### 2. Initialize Git Repository (Recommended)

This repo includes helper scripts to bootstrap a new git repository on GitHub. 

**Why use this?**
The Aku Loop works best when it can commit and push changes after every iteration. This allows you to:
- Review each autonomous step in your git history.
- Revert safely if the agent goes off track.
- Maintain a remote backup.

```bash
# Bash: Initialize git repo + create private GitHub remote
./setup_git_repo.sh
```

```powershell
# PowerShell: Initialize git repo + create private GitHub remote
.\setup_git_repo.ps1
```

*Requires [GitHub CLI](https://cli.github.com/) (`gh`) to be installed and authenticated (`gh auth login`).*

### 3. Move Files & Configure

Move the setup files to your project root (if they aren't already there):

```bash
# If you cloned/downloaded this repo to 'Aku-Loop', copy the files to 'my-project'
cp -r Aku-Loop/files/bash/* my-project/
# OR
Copy-Item -Recurse Aku-Loop\files\pwsh\* my-project\
```

Then create your specifications directory:

```bash
mkdir specs
```


### 4. Configure AGENTS.md

Edit `AGENTS.md` with your project's build, test, and validation commands.

### 5. Run the Loop

See [Quick Start](#quick-start) above.

---


## Repository Structure

> **Note:** The following directories are excluded from version control via `.gitignore` and are not pushed to GitHub: `_archive/` and `test-project/`.

```
Aku-Loop/
├── README.md                # This file
├── CLAUDE.md                # Guidance for Claude Code
├── LICENSE                  # License file
├── .gitignore               # Git ignore rules
├── artifacts/               # Images and other static assets
├── files/                   # Main implementation (not ignored)
│   ├── bash/                # Bash/Linux/macOS scripts and templates
│   │   ├── aku-loop-specs.sh
│   │   ├── aku-loop-plan.sh
│   │   ├── aku-loop-build.sh
│   │   ├── setup_git_repo.sh
│   │   ├── PROMPT_specs_interview.md
│   │   ├── PROMPT_build.md
│   │   ├── PROMPT_plan.md
│   │   ├── AGENTS.md
│   │   ├── IMPLEMENTATION_PLAN.md
│   │   ├── specs/           # Example specs (not tracked in template)
│   │   └── src/             # Example src (not tracked in template)
│   └── pwsh/                # PowerShell/Windows scripts and templates
│       ├── aku-loop-specs.ps1
│       ├── aku-loop-plan.ps1
│       ├── aku-loop-build.ps1
│       ├── setup_git_repo.ps1
│       ├── PROMPT_specs_interview.md
│       ├── PROMPT_build.md
│       ├── PROMPT_plan.md
│       ├── AGENTS.md
│       ├── IMPLEMENTATION_PLAN.md
│       ├── logs/            # Log files (gitignored)
│       ├── specs/           # Example specs (gitignored)
│       └── src/             # Example src (gitignored)
├── artifacts/               # Images and other static assets

```

**Key points:**
- `_archive/` and `test-project/` are excluded from version control and are not pushed to GitHub.
- `logs/`, `specs/`, and `src/` inside implementation folders are also gitignored by default.
- Only the main scripts, prompts, and templates in `files/bash/` and `files/pwsh/` are tracked.
- The root contains only essential project files and documentation.

---



## Loop Mechanics

### Outer Loop Control

**Minimal form:**
```bash
# How the loop works conceptually (pseudo-code)
while true; do 
    run_claude_agent(PROMPT)
    git_commit_changes()
    if no_more_tasks; then break; fi
done
```

**How task continuation works:**
1. Bash/PowerShell loop runs → feeds `PROMPT_{mode}.md` to claude
2. **PLAN Mode**: Agent reads specs, checks code, updates `IMPLEMENTATION_PLAN.md`.
3. **BUILD Mode**: Agent reads `IMPLEMENTATION_PLAN.md`, picks top task, implements it, runs tests, commits code.
4. **Loop restarts** immediately → fresh context window for the next task.

**Key insight:** The `IMPLEMENTATION_PLAN.md` file persists on disk between iterations, acting as shared state. No sophisticated orchestration needed.

### Script Usage

| Feature | Description |
|---------|-------------|
| **Pre-flight Checks** | Validates specs/, AGENTS.md, and claude CLI exist before starting |
| **Configurable Model** | `--model` flag to override default (opus/sonnet/etc) |
| **Log File Output** | Writes JSON output to timestamped log files in `./logs/` |
| **Iteration Summary** | Displays files read/created/edited, tool calls per iteration |
| **Cooldown Timer** | Optional delay between iterations to prevent rate limiting |
| **Resume Capability** | `--resume` flag to continue from last saved iteration |
| **Exit Code Handling** | Stops loop on critical failures (exit code > 1) |
| **Auto-Completion (Build)** | Detects when all tasks are done and exits gracefully |

**Bash (`aku-loop-plan.sh`, `aku-loop-build.sh`, `aku-loop-specs.sh`):**
```bash
./aku-loop-specs.sh                  # Interactive specs interview
./aku-loop-build.sh                  # Build mode, unlimited
./aku-loop-build.sh 20               # Build mode, max 20 iterations
./aku-loop-plan.sh                   # Plan mode, unlimited
./aku-loop-plan.sh 5                 # Plan mode, max 5 iterations
./aku-loop-build.sh --model sonnet   # Use sonnet model instead of opus
./aku-loop-build.sh --cooldown 30    # 30s delay between iterations
./aku-loop-build.sh --resume         # Resume interrupted run
./aku-loop-build.sh --log-dir ./logs # Custom log directory
./aku-loop-build.sh --no-log         # Disable file logging
```

**PowerShell (`aku-loop-plan.ps1`, `aku-loop-build.ps1`, `aku-loop-specs.ps1`):**
```powershell
.\aku-loop-specs.ps1                 # Interactive specs interview
.\aku-loop-build.ps1                 # Build mode, unlimited
.\aku-loop-build.ps1 -MaxIterations 20
.\aku-loop-plan.ps1                  # Plan mode, unlimited
.\aku-loop-plan.ps1 -MaxIterations 5
.\aku-loop-build.ps1 -Model sonnet   # Use sonnet model
.\aku-loop-build.ps1 -Cooldown 30    # 30s delay between iterations
.\aku-loop-build.ps1 -Resume         # Resume interrupted run
.\aku-loop-build.ps1 -LogDir ./logs  # Custom log directory
.\aku-loop-build.ps1 -NoLog          # Disable file logging
```


**State File:** The loop scripts create a `.aku_loop_state` file to track iteration progress. This file is automatically cleaned up on successful completion.

### Git-Optional Operation

Both scripts automatically detect if running inside a git repository:

- **In git repo**: Normal behavior with commits and pushes after each iteration
- **No git repo**: Skips git operations, loop continues without version control

This allows experimentation and learning without requiring git initialization.

### Claude CLI Flags Used

| Flag | Purpose |
|------|---------|
| `-p` | Headless mode (reads prompt from stdin) |
| `--dangerously-skip-permissions` | Auto-approve all tool calls (required for autonomous operation) |
| `--output-format=stream-json` | Structured output for logging/monitoring |
| `--model opus` | Uses Opus for complex reasoning (task selection, prioritization) |
| `--verbose` | Detailed execution logging |

**Security Warning:** `--dangerously-skip-permissions` bypasses Claude's permission system. Running without a sandbox exposes credentials, cookies, and tokens. Run in isolated environments with minimum viable access.

---

## Configuration

### AGENTS.md

The single, canonical "heart of the loop"—a concise operational guide (~50 lines max):

```markdown
## Build & Run

Succinct rules for how to BUILD the project:

## Validation

Run these after implementing to get immediate feedback:

- Tests: `[test command]`
- Typecheck: `[typecheck command]`
- Lint: `[lint command]`

## Operational Notes

Succinct learnings about how to RUN the project:

...

### Codebase Patterns

...
```

**Critical:** Keep `AGENTS.md` brief. Status updates belong in `IMPLEMENTATION_PLAN.md`. A bloated `AGENTS.md` pollutes every future loop's context.


### IMPLEMENTATION_PLAN.md

- Generated by Aku Loop during PLANNING mode
- Updated during BUILDING mode (mark complete, add discoveries)
- No predefined template—let Aku Loop/LLM dictate format
- Acts as shared state between iterations
- Can be regenerated anytime—disposable

### SPECS_INTERVIEW.md

- Created automatically by `aku-loop-specs` interactive mode.
- Serves as the shared buffer between You and the Product Manager Agent.
- Contains the full conversation history of the requirements gathering session.

### Model Remapping: OPTIONAL

I cannot afford Claude so I use different models in Claude Code. Below is an example of "how-to" use GLM models or similarly switch to local models. 
These are shortcuts that can be remapped to any LLM family via Claude Code settings:

Windows PowerShell

          ```json 
          (base) PS C:\Users\$USER> more .claude\settings.json 
          {
            "env": {
              "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-4.5-air",
              "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-4.7",
              "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-4.7"
            }
          }
          ```
          ```cli
              (base) PS C:\Users\$USER$> $env:ANTHROPIC_AUTH_TOKEN
              6ThisIsFakeToken7bo2WcMJ28c55VnvZ78vd2.Qj9a43LYB44ZC39
              (base) PS C:\Users\$USER$> $env:ANTHROPIC_BASE_URL
              https://api.z.ai/api/anthropic
          ```

Linux/macOS

          ```json 
          $ cat ~/.claude/settings.json 
          {
            "env": {
              "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-4.5-air",
              "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-4.7",
              "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-4.7"
            }
          }
          ```
        ```cli
          $ echo $ANTHROPIC_AUTH_TOKEN
          6ThisIsFakeToken7bo2WcMJ28c55VnvZ78vd2.Qj9a43LYB44ZC39
          $ echo $ANTHROPIC_BASE_URL
          https://api.z.ai/api/anthropic
          ```
          

This allows using GPT, GLM, or other models while keeping the prompts unchanged.

---

---
![Aku mini](artifacts/Aku-mini.jpg)

## Acknowledgments

  This implementation builds on the work of many talented individuals, and all I have done is build a little bit on top of their inspiratonal work. No credit or creativity asserted by me. I am just happy that I have acceess to so much talent to learn from.

- **Clayton Farr** – [The Ralph Playbook](https://ClaytonFarr.github.io/ralph-playbook/) (comprehensive methodology guide)
- **Geoffrey Huntley** – Original creator of [Ralph](https://ghuntley.com/ralph/)
- **Matt Pocock** – Early overview and explanations
- **Ryan Carson** – Community documentation
- and many more who have contributed to the Ralph Method community.

## Inspiration
- **Aku Tembe** - the bestest boi. 

---

## License

This repository is a practical implementation of the Ralph Method. See original sources for licensing information. No claims or creativity is asserted by me or Aku!
