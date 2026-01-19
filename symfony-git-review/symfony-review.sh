#!/bin/bash

# ========================================
# Symfony Git Diff Review Script
# Context-Aware Code Review with Flexible Version Support
# Author: Anis Ajengui
# Version: 1.4.4 - Added support for older Symfony/PHP versions
# ========================================

set -euo pipefail

# === Configuration ===
CONFIG_FILE=".vscode/review-config.json"
SYMFONY_VERSION="7.3" # Default, overridden by config or detection
PHP_VERSION="8.4"     # Default, overridden by config or detection
BASE_BRANCH="origin/main"
FEATURE_BRANCH=""
SHOW_REVIEW=false
VERBOSE=false
SCAN_CONTEXT=true
AI_PROVIDER="copilot" # copilot, claude, gpt
PRIORITIZE_LATEST=true

# === Colors ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# === File Paths ===
VSCODE_DIR=".vscode"
DIFF_PATH="$VSCODE_DIR/mr.diff"
CHANGED_FILES_PATH="$VSCODE_DIR/changed-files.txt"
CONTEXT_PATH="$VSCODE_DIR/project-context.md"
DIFF_CONTEXT_PATH="$VSCODE_DIR/diff-context.md"
REVIEW_PROMPT="$VSCODE_DIR/symfony-code-review-prompt.md"
REVIEW_OUTPUT="$VSCODE_DIR/review-output.md"
COMMENTS_DELIVERABLE="$VSCODE_DIR/review-comments-deliverable.md"
CONFIG_FILE="$VSCODE_DIR/review-config.json"
FEATURES_MATRIX="$VSCODE_DIR/symfony-features-matrix.md"

# === Version-Specific Documentation URLs ===
get_symfony_doc_url() {
    local version="$1"
    local major_minor=$(echo "$version" | cut -d. -f1,2)
    echo "https://symfony.com/doc/$major_minor"
}

get_php_doc_url() {
    local version="$1"
    local major_minor=$(echo "$version" | cut -d. -f1,2)
    echo "https://www.php.net/manual/en/migration${major_minor//./}.php"
}

# === Logging Functions ===
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
    exit 1
}

log_verbose() {
    if $VERBOSE; then
        echo -e "${PURPLE}🔍 $1${NC}"
    fi
}

log_feature() {
    echo -e "${CYAN}🆕 $1${NC}"
}

# === Load Version Config ===
load_version_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_warning "First-time setup: Configure project versions"
        
        SYMFONY_DETECTED=$(grep -oP '"name": "symfony/framework-bundle",\s*"version": "\K[\d.]+' composer.lock 2>/dev/null || echo "7.3")
        PHP_DETECTED=$(grep -oP '"php": "\K[\d.]+' composer.json 2>/dev/null || php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
        
        read -p "Enter Symfony version [${SYMFONY_DETECTED}]: " symfony_ver
        read -p "Enter PHP version [${PHP_DETECTED}]: " php_ver
        
        SYMFONY_VERSION="${symfony_ver:-${SYMFONY_DETECTED}}"
        PHP_VERSION="${php_ver:-${PHP_DETECTED}}"
        
        jq -n --arg sv "$SYMFONY_VERSION" \
              --arg pv "$PHP_VERSION" \
              '{ "symfony_version": $sv, "php_version": $pv }' > "$CONFIG_FILE"
        
        log_success "Configuration saved to $CONFIG_FILE"
    else
        SYMFONY_VERSION="$(jq -r .symfony_version "$CONFIG_FILE" 2>/dev/null || echo "7.3")"
        PHP_VERSION="$(jq -r .php_version "$CONFIG_FILE" 2>/dev/null || echo "8.4")"
    fi
    
    # Validate versions
    if [[ ! "$SYMFONY_VERSION" =~ ^[5-7]\.[0-9]+(\.[0-9]+)?$ ]]; then
        log_error "Invalid Symfony version: $SYMFONY_VERSION (must be ≥ 5.4)"
    fi
    if [[ ! "$PHP_VERSION" =~ ^[7-8]\.[0-9]+(\.[0-9]+)?$ ]]; then
        log_error "Invalid PHP version: $PHP_VERSION (must be ≥ 7.4)"
    fi
    
    SYMFONY_DOC_URL=$(get_symfony_doc_url "$SYMFONY_VERSION")
    PHP_DOC_URL=$(get_php_doc_url "$PHP_VERSION")
}

# === Show Usage ===
show_usage() {
    cat << USAGE
🎯 Symfony Git Diff Review Script v1.4.4 - Context-Aware Analysis

Usage: $0 <feature-branch> [options]

Arguments:
  feature-branch    The feature branch to review (required)

Options:
  --base BRANCH     Base branch for comparison (default: origin/main)
  --show            Show review output after generation
  --verbose         Enable verbose output
  --no-context      Skip project context scanning
  --latest          Enable latest Symfony features prioritization
  --ai PROVIDER     AI provider: copilot|claude|gpt (default: copilot)
  --help            Show this help message

Examples:
  $0 feature/user-authentication
  $0 feature/api-endpoints --show --verbose
  $0 hotfix/security-fix --base origin/develop --ai claude

📁 All files are generated in .vscode/ directory (git-ignored)
🆕 NEW: Supports Symfony ≥ 5.4 and PHP ≥ 7.4
USAGE
}

# === Dependency Check ===
check_dependencies() {
    log_verbose "Checking dependencies..."
    for cmd in git jq bc; do
        if ! command -v "$cmd" &>/dev/null; then
            log_error "Required dependency '$cmd' not found. Install it using: sudo apt install $cmd"
        fi
    done
    if [[ "$AI_PROVIDER" == "copilot" ]]; then
        if ! command -v gh &>/dev/null; then
            log_warning "GitHub CLI ('gh') not found. Required for Copilot integration. Install with: sudo apt install gh"
        fi
    fi
}

# === Parse Arguments ===
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --base)
                if [[ -z "$2" ]]; then
                    log_error "--base requires a branch name"
                fi
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
            --latest)
                PRIORITIZE_LATEST=true
                shift
                ;;
            --ai)
                if [[ -z "$2" ]]; then
                    log_error "--ai requires a provider (copilot|claude|gpt)"
                fi
                AI_PROVIDER="$2"
                shift 2
                ;;
            --help)
                show_usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                ;;
            *)
                if [ -z "$FEATURE_BRANCH" ]; then
                    FEATURE_BRANCH="$1"
                else
                    log_error "Unexpected argument: $1"
                fi
                shift
                ;;
        esac
    done
}

# === Validate Arguments ===
validate_arguments() {
    if [ -z "$FEATURE_BRANCH" ]; then
        log_error "Feature branch is required"
    fi
    
    if ! git rev-parse --git-dir &>/dev/null; then
        log_error "Not in a git repository"
    fi
    
    if ! git rev-parse --verify "$FEATURE_BRANCH" &>/dev/null; then
        log_error "Feature branch '$FEATURE_BRANCH' does not exist"
    fi
}

# === Generate Features Matrix ===
generate_features_matrix() {
    log_feature "Generating features matrix for Symfony $SYMFONY_VERSION and PHP $PHP_VERSION..."
    local symfony_major_minor=$(echo "$SYMFONY_VERSION" | cut -d. -f1,2)
    local php_major_minor=$(echo "$PHP_VERSION" | cut -d. -f1,2)
    
    cat > "$FEATURES_MATRIX" << FEATURES
# 🆕 Symfony $SYMFONY_VERSION & PHP $PHP_VERSION Features Matrix

## 🎯 Version-Specific Guidelines
- **Symfony Documentation**: [$symfony_major_minor]($SYMFONY_DOC_URL)
- **PHP Migration Guide**: [$php_major_minor]($PHP_DOC_URL)
- **Version Focus**: Symfony $SYMFONY_VERSION and PHP $PHP_VERSION

## 🚨 Critical Checks
### PHP $PHP_VERSION Features
$(if [[ "$php_major_minor" > "7.4" || "$php_major_minor" == "7.4" ]]; then
    echo "- ✅ Strict Types: Supported (declare(strict_types=1))"
    echo "- ✅ Arrow Functions: Supported"
fi)
$(if [[ "$php_major_minor" > "8.0" || "$php_major_minor" == "8.0" ]]; then
    echo "- ✅ Union Types: Supported"
    echo "- ✅ Named Arguments: Supported"
    echo "- ✅ Attributes: Supported"
fi)
$(if [[ "$php_major_minor" > "8.1" || "$php_major_minor" == "8.1" ]]; then
    echo "- ✅ Readonly Properties: Supported"
    echo "- ✅ Enums: Supported"
fi)
$(if [[ "$php_major_minor" > "8.4" || "$php_major_minor" == "8.4" ]]; then
    echo "- ✅ Property Hooks: Supported"
    echo "- ✅ Asymmetric Visibility: Supported"
    echo "- ✅ New Array Functions: Supported (e.g., array_find)"
fi)

### Symfony $SYMFONY_VERSION Features
$(if [[ "$symfony_major_minor" > "5.4" || "$symfony_major_minor" == "5.4" ]]; then
    echo "- ✅ Modern Directory Structure: Supported"
    echo "- ✅ SymfonyStyle: Use for console output"
fi)
$(if [[ "$symfony_major_minor" > "6.0" || "$symfony_major_minor" == "6.0" ]]; then
    echo "- ✅ Native Attributes: Supported (e.g., #[Route])"
fi)
$(if [[ "$symfony_major_minor" > "6.2" || "$symfony_major_minor" == "6.2" ]]; then
    echo "- ✅ MapRequestPayload: Use #[MapRequestPayload]"
    echo "- ✅ AsConsoleCommand: Use #[AsConsoleCommand]"
fi)
$(if [[ "$symfony_major_minor" > "7.3" || "$symfony_major_minor" == "7.3" ]]; then
    echo "- ✅ DatePoint: Use Symfony\Component\Clock\DatePoint"
    echo "- ✅ AsEventListener: Use #[AsEventListener]"
fi)

## 🔍 Detection Patterns
### PHP Incompatible Patterns
$(if [[ "$php_major_minor" < "8.0" ]]; then
    echo "- Union Types: type1|type2"
    echo "- Named Arguments: func(arg: value)"
fi)
$(if [[ "$php_major_minor" < "8.1" ]]; then
    echo "- Readonly Properties: readonly string \$prop"
    echo "- Match Expression: match(\$value) { ... }"
fi)
$(if [[ "$php_major_minor" < "8.4" ]]; then
    echo "- Property Hooks: public \$prop { get => ...; }"
    echo "- Asymmetric Visibility: public(private(set)) \$prop"
fi)

### Symfony Incompatible Patterns
$(if [[ "$symfony_major_minor" < "6.0" ]]; then
    echo "- Native Attributes: #[Route(...)]"
fi)
$(if [[ "$symfony_major_minor" < "6.2" ]]; then
    echo "- MapRequestPayload: #[MapRequestPayload]"
    echo "- AsConsoleCommand: #[AsConsoleCommand]"
fi)
$(if [[ "$symfony_major_minor" < "7.3" ]]; then
    echo "- DatePoint: Symfony\Component\Clock\DatePoint"
    echo "- AsEventListener: #[AsEventListener]"
fi)

## 🛠️ Recommendations
- Use [Symfony $SYMFONY_VERSION Docs]($SYMFONY_DOC_URL)
- Verify PHP $PHP_VERSION compatibility with [PHP $PHP_VERSION Migration]($PHP_DOC_URL)
- Adopt version-appropriate console command practices
FEATURES
    log_success "Features matrix generated -> $FEATURES_MATRIX"
}

# === Generate Diff ===
generate_diff() {
    log_info "Fetching latest changes from origin..."
    git fetch origin &>/dev/null || log_warning "Failed to fetch from origin"
    
    log_info "Generating diff between $BASE_BRANCH and $FEATURE_BRANCH..."
    if ! git diff "$BASE_BRANCH...$FEATURE_BRANCH" --color-moved=default > "$DIFF_PATH"; then
        log_error "Failed to generate diff"
    fi
    
    if [ ! -s "$DIFF_PATH" ]; then
        log_warning "No changes detected"
        exit 0
    fi
    
    log_info "Analyzing changed files..."
    git diff --name-only "$BASE_BRANCH...$FEATURE_BRANCH" -- '*.php' '*.twig' '*.js' '*.css' '*.scss' > "$CHANGED_FILES_PATH"
    CHANGED_FILES_COUNT=$(wc -l < "$CHANGED_FILES_PATH")
    DIFF_SIZE=$(wc -l < "$DIFF_PATH")
    
    log_success "Git diff generated ($DIFF_SIZE lines, $CHANGED_FILES_COUNT files) -> $DIFF_PATH"
    log_verbose "Changed files saved to -> $CHANGED_FILES_PATH"
}

# === Scan Project Context ===
scan_project_context() {
    log_info "Scanning global project context for architecture awareness..."
    
    TOTAL_PHP_FILES=$(find src tests -name "*.php" 2>/dev/null | wc -l || echo 0)
    TOTAL_TWIG_FILES=$(find templates -name "*.twig" 2>/dev/null | wc -l || echo 0)
    TOTAL_JS_FILES=$(find assets -name "*.js" 2>/dev/null | wc -l || echo 0)
    TOTAL_CSS_FILES=$(find assets -name "*.css" -o -name "*.scss" 2>/dev/null | wc -l || echo 0)
    
    cat > "$CONTEXT_PATH" << CONTEXT
# Global Project Context Analysis

## Project Technology Stack
- **Symfony Version**: $SYMFONY_VERSION
- **PHP Version**: $PHP_VERSION
- **Twig Files**: $TOTAL_TWIG_FILES
- **JavaScript Files**: $TOTAL_JS_FILES
- **CSS/SCSS Files**: $TOTAL_CSS_FILES

## Version Compatibility
- **Target Versions**: Symfony $SYMFONY_VERSION ([Docs]($SYMFONY_DOC_URL)), PHP $PHP_VERSION ([Migration]($PHP_DOC_URL))

## Project Structure
\`\`\`
$(find src tests templates assets -type f 2>/dev/null | head -20 | sort)
$(if [ $(find src tests templates assets -type f 2>/dev/null | wc -l) -gt 20 ]; then echo "... and $(( $(find src tests templates assets -type f 2>/dev/null | wc -l) - 20 )) more files"; fi)
\`\`\`

## Technology Specifics
### PHP $PHP_VERSION Features
$(if [[ "$PHP_VERSION" > "7.4" || "$PHP_VERSION" == "7.4" ]]; then echo "- Strict types, arrow functions"; fi)
$(if [[ "$PHP_VERSION" > "8.0" || "$PHP_VERSION" == "8.0" ]]; then echo "- Union types, named arguments, attributes"; fi)
$(if [[ "$PHP_VERSION" > "8.1" || "$PHP_VERSION" == "8.1" ]]; then echo "- Readonly properties, enums"; fi)
$(if [[ "$PHP_VERSION" > "8.4" || "$PHP_VERSION" == "8.4" ]]; then echo "- Property hooks, asymmetric visibility, new array functions"; fi)

### Symfony $SYMFONY_VERSION Features
$(if [[ "$SYMFONY_VERSION" > "5.4" || "$SYMFONY_VERSION" == "5.4" ]]; then echo "- Modern directory structure, SymfonyStyle for console"; fi)
$(if [[ "$SYMFONY_VERSION" > "6.0" || "$SYMFONY_VERSION" == "6.0" ]]; then echo "- Native attributes (e.g., #[Route])"; fi)
$(if [[ "$SYMFONY_VERSION" > "6.2" || "$SYMFONY_VERSION" == "6.2" ]]; then echo "- MapRequestPayload, AsConsoleCommand"; fi)
$(if [[ "$SYMFONY_VERSION" > "7.3" || "$SYMFONY_VERSION" == "7.3" ]]; then echo "- DatePoint, AsEventListener"; fi)

### Twig Features
- Template inheritance, Symfony helpers
$(if [[ "$SYMFONY_VERSION" > "6.0" || "$SYMFONY_VERSION" == "6.0" ]]; then echo "- Stimulus integration (if used)"; fi)

### JavaScript Features
- ES6 modules, arrow functions, DOM manipulation

### CSS/SCSS Features
- CSS variables, SCSS mixins, modern properties
CONTEXT
    log_success "Global project context analyzed -> $CONTEXT_PATH"
}

# === Analyze Diff Context ===
analyze_diff_context() {
    log_info "Analyzing diff-specific context and integration points..."
    local symfony_major_minor=$(echo "$SYMFONY_VERSION" | cut -d. -f1,2)
    local php_major_minor=$(echo "$PHP_VERSION" | cut -d. -f1,2)
    
    cat > "$DIFF_CONTEXT_PATH" << DIFF_CONTEXT
# Diff-Specific Context Analysis

## Changed Files Analysis ($CHANGED_FILES_COUNT files)
\`\`\`
$(cat "$CHANGED_FILES_PATH")
\`\`\`

## File Type Distribution
- PHP Files: $(grep -c "\.php$" "$CHANGED_FILES_PATH" 2>/dev/null || echo "0")
- Twig Files: $(grep -c "\.twig$" "$CHANGED_FILES_PATH" 2>/dev/null || echo "0")
- JavaScript Files: $(grep -c "\.js$" "$CHANGED_FILES_PATH" 2>/dev/null || echo "0")
- CSS/SCSS Files: $(grep -c "\.css$\|\.scss$" "$CHANGED_FILES_PATH" 2>/dev/null || echo "0")

## Version-Specific Checks
$(while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        echo "### $file"
        
        # PHP checks
        if [[ "$file" == *.php ]]; then
            if [[ "$php_major_minor" > "8.4" || "$php_major_minor" == "8.4" ]] && grep -q "public \$[a-zA-Z0-9_]* { get =>" "$file"; then
                echo "- ✅ PHP $PHP_VERSION: Property hooks detected"
            elif [[ "$php_major_minor" < "8.4" ]] && grep -q "public \$[a-zA-Z0-9_]* { get =>" "$file"; then
                echo "- ❌ PHP $PHP_VERSION: Property hooks not supported"
            fi
            if [[ "$php_major_minor" < "8.1" ]] && grep -q "match(" "$file"; then
                echo "- ❌ PHP $PHP_VERSION: Match expression not supported"
            fi
            if grep -q "declare(strict_types=1)" "$file"; then
                echo "- ✅ Strict typing enabled"
            fi
            if grep -q "ini_set" "$file"; then
                echo "- ⚠️ Resource configuration (ini_set) detected; review for production safety"
            fi
        fi
        
        # Symfony checks
        if [[ "$file" == *.php ]]; then
            if [[ "$symfony_major_minor" > "6.2" || "$symfony_major_minor" == "6.2" ]] && grep -q "#\[AsConsoleCommand\]" "$file"; then
                echo "- ✅ Symfony $SYMFONY_VERSION: AsConsoleCommand detected"
            elif [[ "$symfony_major_minor" < "6.2" ]] && grep -q "#\[AsConsoleCommand\]" "$file"; then
                echo "- ❌ Symfony $SYMFONY_VERSION: AsConsoleCommand not supported"
            fi
            if [[ "$symfony_major_minor" > "6.2" || "$symfony_major_minor" == "6.2" ]] && grep -q "#\[MapRequestPayload\]" "$file"; then
                echo "- ✅ Symfony $SYMFONY_VERSION: MapRequestPayload detected"
            elif [[ "$symfony_major_minor" < "6.2" ]] && grep -q "#\[MapRequestPayload\]" "$file"; then
                echo "- ❌ Symfony $SYMFONY_VERSION: MapRequestPayload not supported"
            fi
            if [[ "$symfony_major_minor" > "7.3" || "$symfony_major_minor" == "7.3" ]] && grep -q "Symfony\\Component\\Clock\\DatePoint" "$file"; then
                echo "- ✅ Symfony $SYMFONY_VERSION: DatePoint detected"
            elif [[ "$symfony_major_minor" < "7.3" ]] && grep -q "Symfony\\Component\\Clock\\DatePoint" "$file"; then
                echo "- ❌ Symfony $SYMFONY_VERSION: DatePoint not supported"
            fi
        fi
        
        # Twig checks
        if [[ "$file" == *.twig ]]; then
            if grep -q "{% extends '" "$file"; then
                echo "- ✅ Template inheritance"
            fi
            if [[ "$symfony_major_minor" > "6.0" || "$symfony_major_minor" == "6.0" ]] && grep -q "{{ stimulus_" "$file"; then
                echo "- ✅ Stimulus integration"
            fi
            if grep -q "{% block.*%}.*{% endblock %}" "$file"; then
                echo "- ✅ Proper block structure"
            else
                echo "- ⚠️ Missing or improper block structure"
            fi
        fi
        
        # JavaScript checks
        if [[ "$file" == *.js ]]; then
            if grep -q "import .* from" "$file"; then
                echo "- ✅ ES6 module syntax"
            fi
            if grep -q "const .* =>" "$file"; then
                echo "- ✅ Arrow functions"
            fi
            if grep -q "var " "$file"; then
                echo "- ⚠️ Legacy var usage detected; prefer const/let"
            fi
        fi
        
        # CSS/SCSS checks
        if [[ "$file" == *.css || "$file" == *.scss ]]; then
            if grep -q "@mixin" "$file"; then
                echo "- ✅ SCSS mixins"
            fi
            if grep -q "var(--" "$file"; then
                echo "- ✅ CSS variables"
            fi
            if grep -q "!important" "$file"; then
                echo "- ⚠️ Use of !important detected; consider alternatives"
            fi
        fi
        
        echo ""
    fi
done < "$CHANGED_FILES_PATH")
DIFF_CONTEXT
    log_success "Diff-specific context analyzed -> $DIFF_CONTEXT_PATH"
}

# === Generate Review Prompt ===
generate_review_prompt() {
    log_info "Generating context-aware code review prompt..."
    local symfony_major_minor=$(echo "$SYMFONY_VERSION" | cut -d. -f1,2)
    local php_major_minor=$(echo "$PHP_VERSION" | cut -d. -f1,2)
    
    cat > "$REVIEW_PROMPT" << PROMPT
# 🔍 Context-Aware Symfony Code Review - Symfony $SYMFONY_VERSION & PHP $PHP_VERSION

## 📋 Review Context
- **Feature Branch**: \`$FEATURE_BRANCH\`
- **Base Branch**: \`$BASE_BRANCH\`
- **Target Versions**: Symfony $SYMFONY_VERSION ([Docs]($SYMFONY_DOC_URL)), PHP $PHP_VERSION ([Migration]($PHP_DOC_URL))
- **Lines Changed**: $DIFF_SIZE
- **Files Changed**: $CHANGED_FILES_COUNT
- **Latest Features Priority**: $(if $PRIORITIZE_LATEST; then echo "✅ ENABLED"; else echo "❌ DISABLED"; fi)
- **Primary File**: $(head -n 1 "$CHANGED_FILES_PATH" 2>/dev/null || echo "N/A")

---

## 🚨 **CRITICAL: DOMAIN-DRIVEN, CONTEXT-AWARE ANALYSIS**

**You are conducting a DOMAIN-DRIVEN, CONTEXT-AWARE code review with these MANDATORY principles:**

### 🎯 **ANALYSIS SCOPE**
1. **ONLY REVIEW CHANGES**: Focus exclusively on the git diff
2. **LEVERAGE DOMAIN CONTEXT**: Align with CQRS and DDD patterns (commands, handlers, repositories)
3. **ENSURE INTEGRATION**: Verify seamless integration with existing codebase
4. **VERSION COMPATIBILITY**: Enforce Symfony $SYMFONY_VERSION and PHP $PHP_VERSION constraints
5. **MULTI-LANGUAGE SUPPORT**: Review PHP, Twig, JavaScript (ES6), CSS/SCSS

### 🔍 **REVIEW METHODOLOGY**
- **Changed Files**: Analyze the $CHANGED_FILES_COUNT changed file(s), particularly console commands
- **CQRS Alignment**: Ensure commands follow established patterns (e.g., CreateEventCommand)
- **Performance Focus**: Evaluate resource usage (memory, execution time)
- **Security Posture**: Validate input handling and resource limits
- **Version Checks**: Avoid features beyond Symfony $SYMFONY_VERSION and PHP $PHP_VERSION

---

## 🏗️ **GLOBAL PROJECT CONTEXT**

$(if $SCAN_CONTEXT && [ -f "$CONTEXT_PATH" ]; then
    cat "$CONTEXT_PATH"
    echo ""
fi)

---

## 🔍 **DIFF-SPECIFIC CONTEXT**

$(if $SCAN_CONTEXT && [ -f "$DIFF_CONTEXT_PATH" ]; then
    cat "$DIFF_CONTEXT_PATH"
    echo ""
fi)

### 🛠️ **Command-Specific Analysis**
- **File**: \`src/Contremarque/Command/CreateQuoteCommand.php\`
- **Purpose**: Generates quote fixtures via Symfony console command
- **Key Changes**: Commented out \`ini_set('memory_limit', '-1')\` and \`ini_set('max_execution_time', '0')\`
- **Potential Concerns**:
  - Resource management for fixture generation
  - Lack of progress output for long-running tasks
  - Input validation for command options

---

## 🚨 **CRITICAL REVIEW CRITERIA**

$(if [ -f "$FEATURES_MATRIX" ]; then
    cat "$FEATURES_MATRIX"
    echo ""
fi)

### 📊 **SEVERITY CLASSIFICATION**
- **🚨 CRITICAL**: Uses features beyond Symfony $SYMFONY_VERSION/PHP $PHP_VERSION, security risks, or CQRS violations
- **⚠️ MAJOR**: Misses version-appropriate features or integration issues
- **💡 MINOR**: Optimization opportunities within version constraints

### 🔍 **REVIEW AREAS**

#### 1. 🏗️ **CQRS & Architectural Integration** (HIGHEST PRIORITY)
- **Command Patterns**: Align with existing commands (e.g., CreateEventCommand)
- **Handler Integration**: Ensure command interacts with appropriate handlers
- **Repository Usage**: Verify repository patterns (e.g., DoctrineORMEventRepository)
- **DDD Principles**: Adhere to domain-driven design boundaries

#### 2. 🆕 **Symfony $SYMFONY_VERSION & PHP $PHP_VERSION Features** (HIGH PRIORITY)
$(if [[ "$symfony_major_minor" > "6.2" || "$symfony_major_minor" == "6.2" ]]; then
    echo "- **Console Commands**: Use #[AsConsoleCommand] for declarative setup"
    echo "- **MapRequestPayload**: Use #[MapRequestPayload] for DTO mapping"
elif [[ "$symfony_major_minor" > "5.4" || "$symfony_major_minor" == "5.4" ]]; then
    echo "- **Console Commands**: Use SymfonyStyle for output, configure via configure()"
fi)
$(if [[ "$symfony_major_minor" > "7.3" || "$symfony_major_minor" == "7.3" ]]; then
    echo "- **DatePoint**: Use Symfony\Component\Clock\DatePoint for datetime"
    echo "- **Event Listeners**: Use #[AsEventListener] for event handling"
fi)
$(if [[ "$php_major_minor" > "8.0" || "$php_major_minor" == "8.0" ]]; then
    echo "- **Type Safety**: Use union types, named arguments"
fi)
$(if [[ "$php_major_minor" > "8.4" || "$php_major_minor" == "8.4" ]]; then
    echo "- **Performance**: Use property hooks, new array functions"
fi)
- **Twig/JS/CSS**: Ensure version-appropriate practices (if applicable)

#### 3. 🔒 **Security & Resource Management** (HIGH PRIORITY)
- **Input Validation**: Sanitize command inputs/options
- **Resource Limits**: Avoid unsafe \`ini_set\` calls
- **Error Handling**: Robust exception management

#### 4. 🔧 **Code Quality** (MEDIUM PRIORITY)
- **SOLID Principles**: Ensure single responsibility, dependency inversion
- **Readability**: Clear variable names, consistent formatting
- **Performance**: Optimize loops, queries, and fixture generation

#### 5. 🧪 **Testing Strategy** (MEDIUM PRIORITY)
- **Unit Tests**: Cover command logic with PHPUnit
- **Integration Tests**: Use KernelTestCase for console command testing
- **Mocking**: Align mocks with existing test patterns

---

## 📁 **GIT DIFF ANALYSIS**

\`\`\`diff
$(cat "$DIFF_PATH")
\`\`\`

---

## 🎯 **MANDATORY REVIEW FORMAT**

### 🔍 **Executive Summary**
- **CQRS Integration Score**: X/10 (alignment with command patterns)
- **Feature Adoption Score**: X/10 (use of Symfony $SYMFONY_VERSION/PHP $PHP_VERSION features)
- **Performance Impact Score**: X/10 (resource usage efficiency)
- **Security Posture Score**: X/10 (input validation, resource safety)
- **Overall Assessment**: [Summary of integration, performance, and security]

**Scoring Rubric**:
- 8–10: Excellent integration/feature use
- 5–7: Moderate issues, addressable
- 0–4: Critical flaws requiring immediate attention

### ✅ **Well-Integrated Changes**
- Examples of effective CQRS alignment and feature adoption

### 🚨 **Critical Issues**
- Use of features beyond Symfony $SYMFONY_VERSION/PHP $PHP_VERSION, CQRS violations, or security risks

### ⚠️ **Missed Opportunities**
- Underutilized version-appropriate features
- Integration or performance improvements

### 💡 **Optimizations**
- Code readability, performance tweaks, test enhancements

### 🏗️ **CQRS & Architectural Feedback**
- Impact on domain model and command handling
- Integration with existing handlers/repositories

### 🔒 **Security & Performance Feedback**
- Resource management and input validation improvements
- Performance optimization recommendations

---

## 🚨 **DELIVERABLE: GitHub/GitLab-Ready Comments**

**REQUIREMENTS**:
1. Focus on diff changes only
2. Enforce Symfony $SYMFONY_VERSION and PHP $PHP_VERSION compatibility
3. Reference [Symfony $SYMFONY_VERSION Docs]($SYMFONY_DOC_URL) or [PHP $PHP_VERSION Migration]($PHP_DOC_URL)
4. Provide actionable, CQRS-aligned solutions

### 📝 **Comment Structure**

#### 🔍 Comment #[NUMBER]
**File**: \`path/to/changed/file\`  
**Line**: [LINE_NUMBER]  
**Severity**: 🚨 Critical / ⚠️ Major / 💡 Minor  
**Category**: [CQRS|Security|Performance|PHP|Symfony|Testing]  
**Version Check**: [Symfony $SYMFONY_VERSION|PHP $PHP_VERSION]  

**Issue**:  
[Description of issue, focusing on CQRS, security, or performance]  

**Documentation**:  
[Symfony $SYMFONY_VERSION Docs]($SYMFONY_DOC_URL/[path]) | [PHP $PHP_VERSION Migration]($PHP_DOC_URL)  

**Resolution**:  
[Actionable solution aligned with project context]  

**Example**:  
\`\`\`php
// ❌ Problematic code
[problematic_code]

// ✅ Optimized code
[corrected_code]
\`\`\`

**Estimated Effort**: [Time estimate]  
**Risk**: [Low/Medium/High]  

---

## 🎯 **ANALYSIS BOUNDARIES**

### ✅ **DO ANALYZE**:
- Changes in the git diff
- CQRS and DDD alignment
- Security and performance of console commands
- Symfony $SYMFONY_VERSION and PHP $PHP_VERSION compatibility
- Testing strategy for commands

### ❌ **DO NOT ANALYZE**:
- Unchanged files
- Global refactoring beyond the diff
- Non-diff files

### 🔍 **VERSION GUIDANCE**:
- Use [Symfony $SYMFONY_VERSION Docs]($SYMFONY_DOC_URL)
- Ensure PHP $PHP_VERSION compatibility ([Migration]($PHP_DOC_URL))
- Align with CQRS patterns in project structure
PROMPT
    log_success "Review prompt generated -> $REVIEW_PROMPT"
}

# === Generate Comments Deliverable ===
generate_comments_deliverable() {
    log_info "Generating review comments deliverable..."
    
    cat > "$COMMENTS_DELIVERABLE" << COMMENTS
# 📝 Context-Aware Review Comments Deliverable

## Review Metadata
- **Feature Branch**: \`$FEATURE_BRANCH\`
- **Base Branch**: \`$BASE_BRANCH\`
- **Timestamp**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
- **AI Provider**: $AI_PROVIDER
- **Changed Files**: $CHANGED_FILES_COUNT
- **Diff Lines**: $DIFF_SIZE
- **Versions**: Symfony $SYMFONY_VERSION, PHP $PHP_VERSION

## Instructions
This file contains CQRS-aligned, context-aware review comments for the git diff. Each comment:
- Focuses on changed code
- Enforces Symfony $SYMFONY_VERSION and PHP $PHP_VERSION compatibility
- Addresses security, performance, and testing
- Provides actionable solutions

**To use**:
1. Review comments below
2. Apply suggested changes
3. Re-run the review script to verify

## Comments
$(if [ -f "$REVIEW_OUTPUT" ]; then
    cat "$REVIEW_OUTPUT" | grep -A 20 "^#### 🔍 Comment #[0-9]*" 2>/dev/null || echo "No detailed comments generated by AI. Use $REVIEW_PROMPT manually."
else
    echo "No AI review output available. Use $REVIEW_PROMPT manually."
fi)

## Next Steps
- Address critical and major issues
- Optimize with minor suggestions
- Re-run \`symfony-review $FEATURE_BRANCH --show\`
- Ensure \`.vscode/\` is in \`.gitignore\`
COMMENTS
    log_success "Review comments deliverable generated -> $COMMENTS_DELIVERABLE"
}

# === Execute AI Review ===
execute_ai_review() {
    log_info "Executing AI review with $AI_PROVIDER..."
    
    case "$AI_PROVIDER" in
        "copilot")
            if command -v gh &>/dev/null; then
                log_info "Running GitHub Copilot review..."
                if gh copilot suggest -f "$REVIEW_PROMPT" > "$REVIEW_OUTPUT" 2>&1; then
                    log_success "GitHub Copilot review completed -> $REVIEW_OUTPUT"
                    generate_comments_deliverable
                else
                    log_warning "GitHub Copilot review failed - check $REVIEW_OUTPUT manually"
                    echo "# GitHub Copilot Review Error" > "$REVIEW_OUTPUT"
                    echo "Copilot review failed. Use $REVIEW_PROMPT manually." >> "$REVIEW_OUTPUT"
                    generate_comments_deliverable
                fi
            else
                log_warning "GitHub CLI not found - install 'gh' for Copilot integration"
                echo "# GitHub Copilot Review Placeholder" > "$REVIEW_OUTPUT"
                echo "Use $REVIEW_PROMPT with GitHub Copilot manually." >> "$REVIEW_OUTPUT"
                generate_comments_deliverable
            fi
            ;;
        "claude")
            log_warning "Claude AI integration requires API key setup"
            echo "# Claude AI Review Placeholder" > "$REVIEW_OUTPUT"
            echo "Use $REVIEW_PROMPT with Claude AI manually." >> "$REVIEW_OUTPUT"
            generate_comments_deliverable
            ;;
        "gpt")
            log_warning "GPT integration requires OpenAI API setup"
            echo "# GPT Review Placeholder" > "$REVIEW_OUTPUT"
            echo "Use $REVIEW_PROMPT with ChatGPT manually." >> "$REVIEW_OUTPUT"
            generate_comments_deliverable
            ;;
        *)
            log_error "Invalid AI provider: $AI_PROVIDER"
            ;;
    esac
}

# === Main Execution ===
main() {
    parse_arguments "$@"
    validate_arguments
    check_dependencies
    load_version_config
    mkdir -p "$VSCODE_DIR"
    generate_features_matrix
    generate_diff
    if $SCAN_CONTEXT; then
        scan_project_context
        analyze_diff_context
    fi
    generate_review_prompt
    execute_ai_review
    
    if $SHOW_REVIEW && [ -f "$REVIEW_OUTPUT" ]; then
        log_info "Displaying review output..."
        echo ""
        echo "==================== REVIEW OUTPUT ===================="
        cat "$REVIEW_OUTPUT"
        echo "========================================================"
    fi
    
    echo ""
    log_success "Context-Aware Code Review Generation Complete!"
    echo ""
    echo "📂 Generated Files:"
    echo "   📄 Diff:                $DIFF_PATH"
    echo "   📋 Changed Files:       $CHANGED_FILES_PATH"
    if $SCAN_CONTEXT; then
        echo "   🏢 Global Context:      $CONTEXT_PATH"
        echo "   🔍 Diff Context:        $DIFF_CONTEXT_PATH"
    fi
    echo "   📝 Review Prompt:       $REVIEW_PROMPT"
    echo "   📊 Review Output:       $REVIEW_OUTPUT"
    echo "   📋 Comments Deliverable: $COMMENTS_DELIVERABLE"
    echo "   ⚙️ Configuration:       $CONFIG_FILE"
    echo "   🆕 Features Matrix:     $FEATURES_MATRIX"
    echo ""
    echo "🔧 Next Steps:"
    echo "   1. Review the prompt in $REVIEW_PROMPT"
    echo "   2. Check comments in $COMMENTS_DELIVERABLE"
    echo "   3. Apply suggested improvements to $FEATURE_BRANCH"
    echo "   4. Re-run review to validate changes"
    echo ""
    echo "💡 Tip: Add '$VSCODE_DIR/' to your .gitignore to keep review files local"
}

main "$@"