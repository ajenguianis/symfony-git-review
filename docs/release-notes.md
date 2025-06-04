📝 Release Notes
Version 1.0 (2025-06-04)
🎉 Initial Release
The symfony-git-review tool is a reusable shell script designed to automate code review prompt generation for Symfony projects, ensuring adherence to Symfony best practices, clean architecture (CQRS, DDD, SOLID), and high code quality standards.
✨ Features

Git Diff Generation: Generates a detailed Git diff between a feature branch and a base branch (default: origin/main), saved to .vscode/mr.diff.
Project Context Scanning: Analyzes src and tests directories, composer.json, and configuration files to provide project context, saved to .vscode/project-context.md.
Comprehensive Review Prompt: Creates a Markdown prompt in .vscode/symfony-code-review-prompt.md with detailed objectives for architecture, Symfony best practices, code quality, security, performance, and testing.
AI Integration: Supports GitHub Copilot (default), with placeholders for Claude and OpenAI GPT integration, outputting reviews to .vscode/review-output.md.
Configuration File: Generates a JSON configuration file in .vscode/review-config.json to log session details and generated files.
VS Code Integration: Stores all generated files in .vscode/ to ensure they are git-ignored, with support for VS Code tasks (tasks.json).
Command Line Options:
--base BRANCH: Specify the base branch for comparison.
--show: Display the review output in the terminal.
--verbose: Enable detailed logging.
--no-context: Skip project context scanning for faster execution.
--ai PROVIDER: Choose AI provider (copilot, claude, gpt).


Automation: Includes a GitHub Action (.github/workflows/setup-review-tool.yml) to integrate the tool into Symfony projects, adding scripts and updating .gitignore.
Documentation: Comprehensive guides in docs/ for installation, configuration, examples, and troubleshooting.
Utilities: Includes install.sh, update.sh, and uninstall.sh for easy setup and maintenance.

📋 Requirements

Git: For diff generation and repository operations.
Bash: Version 4.0+ for script execution.
jq: For JSON processing in context scanning.
GitHub CLI (optional): For Copilot integration.
Symfony: Version 6.4 or higher.
PHP: Version 8.3 or higher.

🚀 Getting Started
# Install the tool
curl -sSL https://raw.githubusercontent.com/anisajengui/symfony-git-review/main/utils/install.sh | bash

# Run a review
symfony-review feature/my-branch --show --verbose

📁 Repository Structure

symfony-review.sh: Main script for generating code review prompts.
docs/: Installation, configuration, examples, and release notes.
utils/: Installation, update, and uninstall scripts.
templates/: Base prompt and integration templates.
examples/: Sample diffs and review outputs.
integrations/: AI provider integration scripts.
.github/workflows/: GitHub Action for automated setup.

🔧 Known Limitations

AI Integration: Claude and GPT integrations require manual API setup and custom scripts (placeholders provided).
Large Repositories: Context scanning may be slow for very large projects; use --no-context for faster execution.
Dependency Checks: Assumes jq is installed for JSON parsing; manual installation may be required.

🐛 Bug Fixes

N/A (Initial release).

🔮 Planned Features

Static analysis integration with PHPStan for enhanced context scanning.
Comprehensive test suite in tests/ to validate script behavior.
Direct API calls for Claude and OpenAI with environment variable support.
Custom rule sets in .vscode/review-defaults.json for project-specific checks.
Docker Compose configuration for containerized execution.

🤝 Contributing
Contributions are welcome! Please see the Contributing Guide for details on submitting pull requests, reporting issues, or suggesting features.
📄 License
MIT © Anis Ajengui

Upgrade Instructions: This is the initial release. Run the install.sh script to set up the tool, and ensure .vscode/ is added to your .gitignore.
Feedback: Report issues or suggest improvements at github.com/anisajengui/symfony-git-review/issues.
