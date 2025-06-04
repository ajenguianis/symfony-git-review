#!/bin/bash

# ========================================
# Symfony Git Diff Review Script
# Enhanced Code Quality & Architecture Review
# Author: Anis Ajengui
# Version: 1.0
# ========================================

set -euo pipefail

# === Configuration ===
SYMFONY_VERSION="${SYMFONY_VERSION:-7.2}"
PHP_VERSION="${PHP_VERSION:-8.4}"
BASE_BRANCH="origin/main"
FEATURE_BRANCH=""
SHOW_REVIEW=false
VERBOSE=false
SCAN_CONTEXT=true
AI_PROVIDER="copilot" # copilot, claude, gpt

# === Colors ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# === File Paths ===
VSCODE_DIR=".vscode"
DIFF_PATH="$VSCODE_DIR/mr.diff"
CONTEXT_PATH="$VSCODE_DIR/project-context.md"
REVIEW_PROMPT="$VSCODE_DIR/symfony-code-review-prompt.md"
REVIEW_OUTPUT="$VSCODE_DIR/review-output.md"
CONFIG_FILE="$VSCODE_DIR/review-config.json"

# === Functions ===
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_verbose() {
    if $VERBOSE; then
        echo -e "${PURPLE}🔍 $1${NC}"
    fi
}

show_usage() {
    cat << USAGE
🎯 Symfony Git Diff Review Script v5.0

Usage: $0 <feature-branch> [options]

Arguments:
  feature-branch    The feature branch to review (required)

Options:
  --base BRANCH     Base branch for comparison (default: origin/main)
  --show           Show review output after generation
  --verbose        Enable verbose output
  --no-context     Skip project context scanning
  --ai PROVIDER    AI provider: copilot|claude|gpt (default: copilot)
  --help           Show this help message

Examples:
  $0 feature/user-authentication
  $0 feature/api-endpoints --show --verbose
  $0 hotfix/security-fix --base origin/develop --ai claude

📁 All files are generated in .vscode/ directory (git-ignored)
USAGE
}

# === Parse Arguments ===
while [[ $# -gt 0 ]]; do
    case "$1" in
        --base)
            BASE_BRANCH="$2"
            shift 2
            ;;
        --show)
            SHOW_REVIEW=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --no-context)
            SCAN_CONTEXT=false
            shift
            ;;
        --ai)
            AI_PROVIDER="$2"
            shift 2
            ;;
        --help)
            show_usage
            exit 0
            ;;
        -*)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            if [ -z "$FEATURE_BRANCH" ]; then
                FEATURE_BRANCH="$1"
            else
                log_error "Unexpected argument: $1"
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# === Validation ===
if [ -z "$FEATURE_BRANCH" ]; then
    log_error "Feature branch is required"
    show_usage
    exit 1
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir &>/dev/null; then
    log_error "Not in a git repository"
    exit 1
fi

# Check if feature branch exists
if ! git rev-parse --verify "$FEATURE_BRANCH" &>/dev/null; then
    log_error "Feature branch '$FEATURE_BRANCH' does not exist"
    exit 1
fi

# Create .vscode directory
mkdir -p "$VSCODE_DIR"

# === Step 1: Fetch and Generate Diff ===
log_info "Fetching latest changes from origin..."
git fetch origin &>/dev/null || log_warning "Failed to fetch from origin"

log_info "Generating diff between $BASE_BRANCH and $FEATURE_BRANCH..."
if ! git diff "$BASE_BRANCH...$FEATURE_BRANCH" --color-moved=default > "$DIFF_PATH"; then
    log_error "Failed to generate diff"
    exit 1
fi

if [ ! -s "$DIFF_PATH" ]; then
    log_warning "No changes detected in $FEATURE_BRANCH relative to $BASE_BRANCH"
    exit 0
fi

DIFF_SIZE=$(wc -l < "$DIFF_PATH")
log_success "Git diff generated ($DIFF_SIZE lines) -> $DIFF_PATH"

# === Step 2: Scan Project Context ===
scan_project_context() {
    log_info "Scanning project context..."
    
    cat > "$CONTEXT_PATH" << CONTEXT
# Project Context Analysis

## Project Structure
\`\`\`
$(find src tests -type f -name "*.php" 2>/dev/null | head -20 | sort)
$(if [ $(find src tests -type f -name "*.php" 2>/dev/null | wc -l) -gt 20 ]; then echo "... and $(( $(find src tests -type f -name "*.php" 2>/dev/null | wc -l) - 20 )) more files"; fi)
\`\`\`

## Configuration Files
$(ls -la | grep -E "\.(yaml|yml|json|xml)$" 2>/dev/null || echo "No config files found in root")

## Dependencies (composer.json)
$(if [ -f "composer.json" ]; then
    echo "\`\`\`json"
    jq '.require + .["require-dev"] // {}' composer.json 2>/dev/null || cat composer.json | grep -A 50 '"require"'
    echo "\`\`\`"
else
    echo "No composer.json found"
fi)

## Symfony Configuration
$(if [ -d "config" ]; then
    echo "Config files found:"
    find config -name "*.yaml" -o -name "*.yml" | head -10
else
    echo "No config directory found"
fi)

## Entity Analysis
$(if [ -d "src/Entity" ]; then
    echo "Entities found:"
    find src/Entity -name "*.php" | head -10
else
    echo "No Entity directory found"
fi)

## Recent Git Activity
\`\`\`
$(git log --oneline -10 2>/dev/null || echo "No git history available")
\`\`\`
CONTEXT

    log_success "Project context analyzed -> $CONTEXT_PATH"
}

if $SCAN_CONTEXT; then
    scan_project_context
fi

# === Step 3: Generate Review Prompt ===
log_info "Generating comprehensive code review prompt..."

cat > "$REVIEW_PROMPT" << PROMPT
# 🔍 Symfony Code Quality & Architecture Review

## 📋 Review Context
- **Feature Branch:** \`$FEATURE_BRANCH\`
- **Base Branch:** \`$BASE_BRANCH\`
- **Symfony Version:** $SYMFONY_VERSION
- **PHP Version:** $PHP_VERSION
- **Lines Changed:** $DIFF_SIZE

---

## 🎯 Review Objectives

You are a **Senior Symfony Tech Lead** with expertise in clean architecture (CQRS, DDD, SOLID), Symfony best practices, Doctrine ORM, and code quality tools (PHPStan, Rector, ECS, Sonar). Analyze the following Git diff with focus on:

### 1. 🏗️ **Architecture & Design Patterns**
- **SOLID Principles**: Ensure Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, and Dependency Inversion.
- **CQRS/DDD**: Verify command/query separation and domain modeling if applicable.
- **Dependency Injection**: Confirm services are properly injected via constructor or interface.
- **Service Layer**: Check for clear separation of concerns and proper abstractions.
- **Repository Pattern**: Validate repository methods are focused and efficient.

### 2. 🔧 **Symfony Best Practices**
- **Controllers**: Should be slim, delegating to services.
- **Services**: Properly configured with autowiring and tagged appropriately.
- **Events**: Use event dispatcher for decoupled logic.
- **Forms**: Proper validation and handling with Symfony Form component.
- **Security**: Implement voter-based authorization and CSRF protection.
- **Console Commands**: Structured with clear input/output handling.

### 3. 🗄️ **Database & ORM**
- **Entities**: Proper annotations, relationships, and cascade options.
- **Queries**: Avoid N+1 issues, optimize joins, and use query builder appropriately.
- **Migrations**: Safe and reversible database changes.
- **Repositories**: Focused methods with clear intent.

### 4. ✅ **Code Quality**
- **PSR-12**: Adherence to coding standards.
- **Naming**: Clear, consistent, and meaningful names.
- **Type Safety**: Use strict types and return type declarations.
- **Error Handling**: Proper exception handling with specific exceptions.
- **Documentation**: PHPDoc blocks for complex methods.

### 5. 🔒 **Security & Validation**
- **Input Validation**: Use Symfony Validator (@Assert) and form validation.
- **Security**: Check for XSS, SQL injection, and CSRF vulnerabilities.
- **Authorization**: Proper use of security voters or attributes.

### 6. 🧪 **Testing Considerations**
- **Unit Tests**: Cover business logic in services.
- **Integration Tests**: Test API endpoints and database interactions.
- **Functional Tests**: Verify full request-response cycles.
- **Testability**: Ensure code is mockable and decoupled.

### 7. 📊 **Performance**
- **Query Optimization**: Avoid unnecessary database calls.
- **Caching**: Use appropriate caching strategies (e.g., Doctrine cache).
- **Memory Usage**: Optimize for large datasets or loops.

---

## 📁 Git Diff Analysis

\`\`\`diff
$(cat "$DIFF_PATH")
\`\`\`

$(if $SCAN_CONTEXT && [ -f "$CONTEXT_PATH" ]; then
    echo "## 🏢 Project Context"
    echo ""
    cat "$CONTEXT_PATH"
    echo ""
fi)

---

## 🎯 Expected Review Format

Provide your review in the following Markdown structure:

### 🔍 **Summary**
- Brief overview of changes and overall assessment.

### ✅ **Strengths**
- List well-implemented aspects of the code.

### ⚠️ **Issues Found**
- **🚨 Critical**: Must fix before merge (e.g., security issues, broken functionality).
- **⚠️ Major**: Should fix before merge (e.g., architecture violations).
- **💡 Minor**: Suggestions for improvement (e.g., refactoring opportunities).

### 🏗️ **Architecture Feedback**
- Comments on SOLID, CQRS, DDD, and dependency management.

### 🔧 **Symfony-Specific Recommendations**
- Framework-specific improvements (e.g., service configuration, controller structure).

### 📈 **Performance Considerations**
- Potential performance bottlenecks and optimizations.

### 🧪 **Testing Recommendations**
- Suggestions for test coverage and strategies.

### 🎯 **Action Items**
- Prioritized list of changes with specific recommendations and code examples.

---

## 🚨 Special Focus Areas

1. **DateTime Handling**: Flag direct `new DateTime()` usage; recommend `Clock` interface for testability.
2. **Dependency Injection**: Ensure services use interfaces and constructor injection.
3. **Entity Relationships**: Verify cascade options and lazy loading configuration.
4. **Form Validation**: Confirm comprehensive validation rules and error handling.
5. **API Responses**: Check for correct HTTP status codes and response formats (REST/JSON:API).
6. **Exception Handling**: Use specific exception types (e.g., `NotFoundHttpException`).

---

💡 **Provide actionable, specific feedback with code examples where applicable. Ensure recommendations align with Symfony $SYMFONY_VERSION and PHP $PHP_VERSION best practices.**
PROMPT

log_success "Review prompt generated -> $REVIEW_PROMPT"

# === Step 4: Generate Configuration ===
cat > "$CONFIG_FILE" << CONFIG
{
  "review_session": {
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "feature_branch": "$FEATURE_BRANCH",
    "base_branch": "$BASE_BRANCH",
    "diff_lines": $DIFF_SIZE,
    "symfony_version": "$SYMFONY_VERSION",
    "php_version": "$PHP_VERSION",
    "context_scanned": $SCAN_CONTEXT,
    "ai_provider": "$AI_PROVIDER"
  },
  "files_generated": [
    "$DIFF_PATH",
    "$REVIEW_PROMPT",
    "$CONTEXT_PATH",
    "$REVIEW_OUTPUT"
  ]
}
CONFIG

# === Step 5: Execute AI Review (Optional) ===
execute_ai_review() {
    case "$AI_PROVIDER" in
        "copilot")
            if command -v gh &>/dev/null; then
                log_info "Executing GitHub Copilot review..."
                if gh copilot suggest -f "$REVIEW_PROMPT" > "$REVIEW_OUTPUT" 2>&1; then
                    log_success "GitHub Copilot review completed"
                else
                    log_warning "GitHub Copilot review failed - check manually"
                fi
            else
                log_warning "GitHub CLI not found - install 'gh' for Copilot integration"
                echo "# GitHub Copilot Review Placeholder" > "$REVIEW_OUTPUT"
                echo "Use the generated prompt with GitHub Copilot manually." >> "$REVIEW_OUTPUT"
            fi
            ;;
        "claude")
            log_info "Claude AI integration would require API key setup"
            echo "# Claude AI Review Placeholder" > "$REVIEW_OUTPUT"
            echo "Use the generated prompt with Claude AI manually." >> "$REVIEW_OUTPUT"
            ;;
        "gpt")
            log_info "GPT integration would require OpenAI API setup"
            echo "# GPT Review Placeholder" > "$REVIEW_OUTPUT"
            echo "Use the generated prompt with ChatGPT manually." >> "$REVIEW_OUTPUT"
            ;;
    esac
}

execute_ai_review

# === Step 6: Display Results ===
if $SHOW_REVIEW && [ -f "$REVIEW_OUTPUT" ]; then
    log_info "Displaying review output..."
    echo ""
    echo "==================== REVIEW OUTPUT ===================="
    cat "$REVIEW_OUTPUT"
    echo "========================================================"
fi

# === Final Summary ===
echo ""
echo "🎉 Code Review Generation Complete!"
echo ""
echo "📂 Generated Files:"
echo "   📄 Diff:         $DIFF_PATH"
echo "   📝 Prompt:       $REVIEW_PROMPT"
if $SCAN_CONTEXT; then
    echo "   🏢 Context:      $CONTEXT_PATH"
fi
echo "   ⚙️  Config:       $CONFIG_FILE"
echo "   📊 Review:       $REVIEW_OUTPUT"
echo ""
echo "🔧 Next Steps:"
echo "   1. Review the generated prompt in $REVIEW_PROMPT"
echo "   2. Use with your preferred AI tool for code review"
echo "   3. Apply suggested improvements to your code"
echo ""
echo "💡 Tip: Add '$VSCODE_DIR/' to your .gitignore to keep review files local"