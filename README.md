# 🎯 Symfony Git Diff Review Tool

> Automated code review generation for Symfony projects with AI integration

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Bash-4.0+-blue.svg)](https://www.gnu.org/software/bash/)
[![Symfony](https://img.shields.io/badge/Symfony-6.4%2B-green.svg)](https://symfony.com/)

## ✨ Features

- 🔍 **Smart Diff Analysis**: Comprehensive Git diff generation
- 🏗️ **Architecture Review**: Validates SOLID, CQRS, and DDD patterns
- 🔧 **Symfony Best Practices**: Ensures framework-specific standards
- 🤖 **AI Integration**: Supports GitHub Copilot, Claude, or GPT
- 📊 **Project Context**: Scans project structure for consistent recommendations
- 🎯 **Actionable Feedback**: Provides prioritized, specific suggestions

## 🚀 Quick Start


### One-line installation
```bash
curl -sSL https://raw.githubusercontent.com/anisajengui/symfony-git-review/main/utils/install.sh | bash
```
### Install required extensions
```bash
sudo apt update
sudo apt install -y jq
```

### Review your feature branch
```bash
symfony-review feature/my-branch --show
```

## 📖 Usage Examples


### Basic usage
```bash
symfony-review feature/user-authentication
```
### Compare against develop branch
```bash
symfony-review feature/api-endpoints --base origin/develop --verbose
```
### Use with Claude AI
```bash
symfony-review hotfix/security-fix --ai claude --show
```
### Skip context scanning for speed
```bash
symfony-review feature/quick-fix --no-context
```

## 📚 Documentation

- [📥 Installation Guide](docs/installation.md)
- [⚙️ Configuration Options](docs/configuration.md)
- [💡 Usage Examples](docs/examples.md)
- [🔧 Troubleshooting](docs/troubleshooting.md)

## 🛠️ Project Integration

### Composer Integration
```json
{
  "scripts": {
    "review": "scripts/review.sh",
    "review:show": "scripts/review.sh --show"
  }
}
```

### VS Code Integration
Press `Ctrl+Shift+P` → "Tasks: Run Task" → "Symfony Code Review"

### CI/CD Integration
Automated reviews on every pull request with GitHub Actions.

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md).

## 📄 License

MIT © [Anis Ajengui](LICENSE)

---

⭐ **Star this repo** if it helps you improve your Symfony code quality!
