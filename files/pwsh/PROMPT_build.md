0a. Read and assimilate `specs/*` using up to 300 concurrent Sonnet subagents to fully understand the product and technical requirements. [web:2][web:4]  
0b. Carefully review @IMPLEMENTATION_PLAN.md to identify current priorities, open items, and known constraints. [web:6]  
0c. When an existing implementation is present, treat `src/*` as the canonical location for source code and study it before introducing changes. [web:2]  
0d. Ensure every newly introduced core source file begins with the standard metadata block: [web:6]  
    @author: {Your_Full_Name}  
    @company: {Your_Company_Name}  
    @created: {Initial_Create_Date}  
    @last_modified: {Current_Date}  

1. Implement behavior strictly according to the specifications, orchestrating work through parallel subagents. Use @IMPLEMENTATION_PLAN.md to select the highest-impact item first. Always search the repository before editing (never assume something is unimplemented) using Sonnet subagents, with up to 500 for read/search operations and a single Sonnet subagent for builds/tests. Escalate to Opus subagents when deeper reasoning is required (complex debugging, design tradeoffs, or architectural choices). [web:2][web:3][web:11]  
2. Once a change is made or a defect is fixed, run the tests that cover the modified module or feature. If you discover missing functionality, extend the code to satisfy the documented behavior in the specs — do not leave gaps. Ultrathink. [web:3][web:8]  
3. Whenever you uncover an issue, immediately record it in @IMPLEMENTATION_PLAN.md with enough detail for another agent to act on it. When you address it, update the entry to reflect completion and remove it if fully resolved. [web:6][web:15]  
4. After all relevant tests pass, update @IMPLEMENTATION_PLAN.md to reflect the completed work, then run `git add -A`, followed by a descriptive `git commit`, and finally `git push` to share the changes. [web:6][web:9]  

99999. When writing documentation, always explain the reasoning and intent behind changes, including why specific tests and implementations are important. [web:6][web:12]  
999999. Maintain a single source of truth in the codebase and specs; avoid creating redundant layers such as migrations/adapters unless explicitly required. If unrelated tests fail, treat them as part of your current increment and fix them. [web:2][web:15]  
9999999. Once the build and all tests are green, create a git tag. If the repository has no tags yet, start at `0.0.0` and bump the patch version by one for the new tag (for example, use `0.0.1` when `0.0.0` is missing). [web:6][web:9]  
99999999. Add extra logging as needed to diagnose problems, but keep it purposeful and avoid noisy output in steady state. [web:2]  
999999999. Keep @IMPLEMENTATION_PLAN.md synchronized with new insights and decisions; future agents will rely on it to avoid repeating analysis. Make a habit of updating it at the end of your turn. [web:6][web:15]  
9999999999. Whenever you refine how to build, run, or interact with the application, capture the minimal operational instructions in @AGENTS.md using a subagent. For example, if you iterate on multiple commands before discovering the correct one, record the final, correct command there. [web:12][web:15]  
99999999999. For any defect you notice, either fix it immediately or document it in @IMPLEMENTATION_PLAN.md using a subagent, even if it is outside the currently selected task. [web:2][web:6]  
999999999999. Deliver end-to-end implementations instead of temporary stubs or placeholders; incomplete wiring causes rework and slows future progress. [web:2][web:8]  
9999999999999. When @IMPLEMENTATION_PLAN.md becomes unwieldy, periodically prune completed items using a subagent so the file remains focused and readable. [web:6]  
99999999999999. If you encounter contradictions or ambiguities in `specs/*`, invoke an Opus 4.5 subagent with `ultrathink` to reconcile and update the specifications. [web:3][web:8]  
999999999999999. IMPORTANT: Restrict @AGENTS.md to concise, operational guidance only (commands, workflows, environment notes). Use @IMPLEMENTATION_PLAN.md for progress tracking, status, and narrative updates so AGENTS.md remains lean and useful for every future loop. [web:12][web:15]