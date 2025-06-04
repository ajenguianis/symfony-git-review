# 💡 Usage Examples

## 🎯 Basic Usage

### Simple Feature Review
```bash
# Review a feature branch against main
symfony-review feature/user-authentication

# Output:
# ✅ Git diff generated (247 lines) -> .vscode/mr.diff
# ✅ Project context analyzed -> .vscode/project-context.md
# ✅ Review prompt generated -> .vscode/symfony-code-review-prompt.md
# 🎉 Code Review Generation Complete!
```

### Show Results Immediately
```bash
symfony-review feature/api-endpoints --show

# Displays the AI-generated review in terminal after generation
```

## 🔧 Advanced Usage

### Different Base Branch
```bash
# Review against develop instead of main
symfony-review feature/payment-gateway --base origin/develop

# Review against a specific commit
symfony-review feature/hotfix --base abc123f
```

### AI Provider Selection
```bash
# Use GitHub Copilot (default)
symfony-review feature/auth --ai copilot

# Use Claude AI
symfony-review feature/auth --ai claude

# Use OpenAI GPT
symfony-review feature/auth --ai gpt
```

### Verbose Logging
```bash
symfony-review feature/complex-feature --verbose

# Output with detailed logging:
# 🔍 Fetching latest changes from origin...
# 🔍 Comparing origin/main with feature/complex-feature...
# 🔍 Scanning project dependencies...
# 🔍 Analyzing entity relationships...
```

## 🏢 Team Workflows

### Code Review Process
```bash
# 1. Developer creates feature branch
git checkout -b feature/user-profile

# 2. Make changes and commit
git add .
git commit -m "Add user profile functionality"

# 3. Generate review before creating PR
symfony-review feature/user-profile --show --verbose

# 4. Address issues found in review
# 5. Create pull request
```

### Pre-commit Hook
```bash
#!/bin/bash
# .git/hooks/pre-push

BRANCH=$(git branch --show-current)
if [[ $BRANCH == feature/* ]]; then
    echo "🔍 Running code review check..."
    symfony-review "$BRANCH" --no-context
    
    echo "📝 Review generated. Please check .vscode/review-output.md"
    echo "Continue with push? (y/n)"
    read -r response
    if [[ ! $response =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi
```

## 🚀 CI/CD Integration

### GitHub Actions Workflow
```yaml
# .github/workflows/code-review.yml
name: Automated Code Review

on:
  pull_request:
    branches: [main, develop]

jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install Symfony Review Tool
        run: |
          curl -sSL https://raw.githubusercontent.com/anisajengui/symfony-git-review/main/utils/install.sh | bash
          
      - name: Run Code Review
        run: |
          symfony-review ${{ github.head_ref }} --base origin/${{ github.base_ref }} --show > review-output.md
          
      - name: Upload Review Artifact
        uses: actions/upload-artifact@v3
        with:
          name: code-review
          path: .vscode/review-output.md
```