# ⚙️ Configuration Guide

## 🎛️ Command Line Options

### Basic Options
```bash
symfony-review feature/branch    # Basic usage
--base BRANCH                   # Base branch (default: origin/main)
--show                         # Show review output immediately
--verbose                      # Enable verbose logging
--no-context                   # Skip project context scanning
--ai PROVIDER                  # AI provider: copilot|claude|gpt
--help                         # Show help message
```

### Examples
```bash
# Review against develop branch
symfony-review feature/api --base origin/develop

# Use Claude AI with verbose output
symfony-review feature/auth --ai claude --verbose --show

# Quick review without context
symfony-review hotfix/bug --no-context
```

## 🌍 Environment Variables

Set default values for common options:

```bash
# Add to ~/.bashrc or ~/.zshrc
export SYMFONY_REVIEW_BASE_BRANCH="origin/develop"
export SYMFONY_REVIEW_AI_PROVIDER="claude"
export SYMFONY_REVIEW_VERBOSE="true"
export SYMFONY_REVIEW_SYMFONY_VERSION="6.4"
export SYMFONY_REVIEW_PHP_VERSION="8.3"
```

## 📄 Project Configuration

### .vscode/review-defaults.json
Create project-specific defaults:

```json
{
  "base_branch": "origin/develop",
  "ai_provider": "copilot",
  "symfony_version": "6.4",
  "php_version": "8.3",
  "scan_context": true,
  "verbose": false,
  "custom_rules": [
    "no-direct-datetime",
    "require-type-hints",
    "check-security-annotations"
  ]
}
```

## 🏗️ Project Integration

### Composer Scripts
Add to your `composer.json`:

```json
{
  "scripts": {
    "review": "scripts/review.sh",
    "review:show": "scripts/review.sh --show",
    "review:verbose": "scripts/review.sh --verbose --show"
  }
}
```

Usage:
```bash
composer review feature/my-branch
composer review:show feature/my-branch
```

## 🎯 VS Code Integration

### .vscode/tasks.json
```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Symfony Code Review",
            "type": "shell",
            "command": "${workspaceFolder}/scripts/review.sh",
            "args": ["${input:branchName}", "--show", "--verbose"],
            "group": "build",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": false,
                "panel": "new"
            },
            "problemMatcher": []
        }
    ],
    "inputs": [
        {
            "id": "branchName",
            "description": "Feature branch name",
            "default": "feature/",
            "type": "promptString"
        }
    ]
}
```

### .vscode/settings.json
```json
{
    "terminal.integrated.shell.linux": "/bin/bash",
    "files.associations": {
        "*.md": "markdown"
    },
    "files.exclude": {
        ".vscode/mr.diff": true,
        ".vscode/review-*.md": true
    }
}
```

## 🔐 AI Provider Configuration

### GitHub Copilot
```bash
# Authenticate
gh auth login

# Install Copilot extension
gh extension install github/gh-copilot

# Verify
gh copilot --version
```

### Claude API (Custom)
```bash
# Set API key
export CLAUDE_API_KEY="your-api-key"

# Custom integration script
curl -o integrations/claude-api.sh https://raw.githubusercontent.com/anisajengui/symfony-git-review/main/integrations/claude-api.sh
```

### OpenAI Integration
```bash
# Set API key
export OPENAI_API_KEY="your-api-key"

# Custom integration script
curl -o integrations/openai-integration.sh https://raw.githubusercontent.com/anisajengui/symfony-git-review/main/integrations/openai-integration.sh
```

## 📊 Advanced Configuration

### Custom Review Templates
Create custom prompt templates in `.vscode/templates/`:

```markdown
# Custom Security Review Template
Focus specifically on security vulnerabilities:
- SQL injection risks
- XSS vulnerabilities
- CSRF protection
- Authentication bypasses
- Authorization flaws
```

### Performance Optimization
```bash
# Skip heavy operations for large repos
export SYMFONY_REVIEW_MAX_DIFF_SIZE=10000
export SYMFONY_REVIEW_SKIP_LARGE_FILES=true
export SYMFONY_REVIEW_PARALLEL_PROCESSING=true
```