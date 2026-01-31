# Initialize a git repository and create a remote on GitHub.
# Requires GitHub CLI (gh) to be installed and authenticated.

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "Error: GitHub CLI (gh) could not be found." -ForegroundColor Red
    Write-Host "Please install it: https://cli.github.com/" -ForegroundColor Yellow
    Write-Host "Then run 'gh auth login' before running this script." -ForegroundColor Yellow
    exit 1
}

# Initialize git if needed
if (Test-Path ".git") {
    Write-Host "Git repository already initialized." -ForegroundColor Yellow
} else {
    Write-Host "Initializing git repository..." -ForegroundColor Cyan
    git init
    # Rename default branch to main to match modern GitHub defaults
    git branch -M main
}

# Configure identity if needed
$gitUser = git config user.name
if ([string]::IsNullOrWhiteSpace($gitUser)) {
    Write-Host "Configuring git user (Aku Loop default)..." -ForegroundColor Cyan
    git config user.name "Aku Loop"
    git config user.email "dan@loop.local"
}

Write-Host "Adding all files..." -ForegroundColor Cyan
git add .
git commit -m "Initial commit: Aku Loop setup" | Out-Null

# Create repo on GitHub if no remote exists
if (git remote get-url origin 2>$null) {
    Write-Host "Remote 'origin' already exists." -ForegroundColor Yellow
} else {
    Write-Host "Creating GitHub repository..." -ForegroundColor Cyan
    $repoName = Split-Path -Leaf (Get-Location)
    Write-Host "This will create a PRIVATE repository named '$repoName' on GitHub." -ForegroundColor Gray
    
    # Create private repo, set remote 'origin', and push
    # To make it public, change --private to --public
    gh repo create --private --source=. --remote=origin --push
}

Write-Host "✅ Git repository ready and pushed to GitHub." -ForegroundColor Green
