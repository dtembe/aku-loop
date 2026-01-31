#!/bin/bash
# Initialize a git repository and create a remote on GitHub.
# Requires GitHub CLI (gh) to be installed and authenticated.

# Check for gh cli
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) could not be found."
    echo "Please install it: https://cli.github.com/"
    echo "Then run 'gh auth login' before running this script."
    exit 1
fi

# Initialize git if needed
if [ -d ".git" ]; then
    echo "Git repository already initialized."
else
    echo "Initializing git repository..."
    git init
    # Rename default branch to main to match modern GitHub defaults
    git branch -M main
fi

# Configure identity if needed (prevents commit errors in new environments)
if [ -z "$(git config user.name)" ]; then
    echo "Configuring git user (Aku Loop default)..."
    git config user.name "Aku Loop"
    git config user.email "dan@loop.local"
fi

echo "Adding all files..."
git add .
git commit -m "Initial commit: Aku Loop setup" 2>/dev/null || echo "Nothing to init commit"

# Create repo on GitHub if no remote exists
if git remote get-url origin &>/dev/null; then
    echo "Remote 'origin' already exists."
else
    echo "Creating GitHub repository..."
    echo "This will create a PRIVATE repository named $(basename "$PWD") on GitHub."
    echo "Press Ctrl+C to cancel or Enter to continue..."
    read -r
    
    # Create private repo, set remote 'origin', and push
    # To make it public, change --private to --public
    gh repo create --private --source=. --remote=origin --push
fi

echo "✅ Git repository ready and pushed to GitHub."
