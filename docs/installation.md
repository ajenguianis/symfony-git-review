# 📥 Installation Guide

## 🚀 Quick Installation

### Option 1: One-Line Installation (Recommended)
```bash
curl -sSL https://raw.githubusercontent.com/anisajengui/symfony-git-review/main/utils/install.sh | bash
```

### Option 2: Manual Installation
```bash
# Download the script
curl -o symfony-review.sh https://raw.githubusercontent.com/anisajengui/symfony-git-review/main/symfony-review.sh

# Make it executable
chmod +x symfony-review.sh

# Move to PATH (optional)
mv symfony-review.sh ~/.local/bin/symfony-review
```

### Option 3: Project-Specific Installation
```bash
# In your Symfony project root
mkdir -p scripts
curl -o scripts/review.sh https://raw.githubusercontent.com/anisajengui/symfony-git-review/main/symfony-review.sh
chmod +x scripts/review.sh
```

## 🔧 Dependencies

### Required
- **Git** (obviously)
- **Bash** 4.0+
- **jq** (for JSON processing)

### Install jq
```bash
# Ubuntu/Debian
sudo apt install jq

# macOS
brew install jq

# CentOS/RHEL
sudo yum install jq
```

### Optional AI Integrations

#### GitHub Copilot CLI
```bash
# Install GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh

# Login and install Copilot extension
gh auth login
gh extension install github/gh-copilot
```

## 🔄 Updates

```bash
# Update to latest version
curl -sSL https://raw.githubusercontent.com/anisajengui/symfony-git-review/main/utils/update.sh | bash
```

## 🗑️ Uninstallation

```bash
# Clean uninstall
curl -sSL https://raw.githubusercontent.com/anisajengui/symfony-git-review/main/utils/uninstall.sh | bash
```

## ✅ Verification

```bash
# Check installation
symfony-review --help

# Test with a feature branch
symfony-review feature/test-branch --verbose
```