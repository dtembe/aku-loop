# Security Policy

## Supported Versions

This is a small, personal project. There is no formal support window, but I will do my best to respond to security-related issues on the latest tagged release.

## Reporting a Vulnerability

If you believe you have found a security issue related to the scripts, prompts, or documentation:

- Please open a **private** issue or contact me via GitHub (preferred), and
- Avoid including any real secrets, tokens, or proprietary code in the report.

## Safe Usage Guidelines

Because Aku Loop uses autonomous LLM agents and the `claude` CLI with `--dangerously-skip-permissions`, you should:

- Run it only on **non-production** machines and repositories.
- Use disposable branches or throwaway repos while you experiment.
- Store API keys and tokens in environment variables or local config files that are gitignored.
- Avoid running the loop under accounts that have broad, unnecessary access to cloud resources.

Logs (`./logs/`) may contain model responses and file paths. Handle them as you would handle any other developer logs (do not share them publicly if they contain sensitive details).
