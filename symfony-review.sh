#!/bin/bash

# ========================================
# Symfony Git Diff Review Script
# Enhanced Code Quality & Architecture Review with Symfony 7.3+ Priority
# Context-Aware Analysis: Check only diff changes with global project awareness
# Author: Anis Ajengui
# Version: 1.4 - Enhanced with Context-Aware Analysis
# ========================================

set -euo pipefail

# === Configuration ===
SYMFONY_VERSION="${SYMFONY_VERSION:-7.3}"
PHP_VERSION="${PHP_VERSION:-8.4}"
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

show_usage() {
    cat << USAGE
🎯 Symfony Git Diff Review Script v1.4 - Context-Aware Analysis

Usage: $0 <feature-branch> [options]

Arguments:
  feature-branch    The feature branch to review (required)

Options:
  --base BRANCH     Base branch for comparison (default: origin/main)
  --show            Show review output after generation
  --verbose         Enable verbose output
  --no-context      Skip project context scanning
  --no-latest       Disable latest Symfony features prioritization
  --ai PROVIDER     AI provider: copilot|claude|gpt (default: copilot)
  --help            Show this help message

Examples:
  $0 feature/user-authentication
  $0 feature/api-endpoints --show --verbose
  $0 hotfix/security-fix --base origin/develop --ai claude

📁 All files are generated in .vscode/ directory (git-ignored)
🆕 NEW: Context-aware analysis - reviews only diff changes with global project awareness
USAGE
}

# === Dependency Check ===
check_dependencies() {
    log_verbose "Checking dependencies..."
    for cmd in git jq; do
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

check_dependencies

# === Early Argument Validation ===
if [[ $# -eq 0 ]]; then
    log_error "No arguments provided"
    show_usage
    exit 1
fi

# === Parse Arguments ===
while [[ $# -gt 0 ]]; do
    case "$1" in
        --base)
            if [[ -z "$2" ]]; then
                log_error "--base requires a branch name"
                show_usage
                exit 1
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
        --no-latest)
            PRIORITIZE_LATEST=false
            shift
            ;;
        --ai)
            if [[ -z "$2" ]]; then
                log_error "--ai requires a provider (copilot|claude|gpt)"
                show_usage
                exit 1
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

# === Step 1: Generate Symfony Features Matrix ===
generate_features_matrix() {
    if $PRIORITIZE_LATEST; then
        log_feature "Generating Symfony 7.3+ features priority matrix..."
        
        cat > "$FEATURES_MATRIX" << FEATURES
# 🆕 Symfony 7.3+ Features Priority Matrix

## 🎯 PRIORITY 1: Must Use Latest Features (Critical)

### ⏰ Date/Time Handling
- **DatePoint over DateTimeImmutable**
  - ✅ Use: \`Symfony\Component\Clock\DatePoint\`
  - ❌ Avoid: \`DateTimeImmutable\`, \`new DateTime()\`
  - 📍 Detection: Look for \`DateTimeImmutable\`, \`DateTime\` in changed files
  - 🔧 Fix: Replace with DatePoint for Clock component integration

### 🚀 Command Improvements
- **Invokable Commands with Attributes**
  - ✅ Use: Attribute-based command configuration
  - ❌ Avoid: Traditional command registration
  - 📍 Detection: Commands extending Command without modern attributes
  - 🔧 Fix: Implement invokable pattern with PHP attributes

### 🗄️ Doctrine Enhancements
- **DatePointType for Doctrine**
  - ✅ Use: \`DatePointType\` in entity mappings
  - ❌ Avoid: \`datetime_immutable\` type
  - 📍 Detection: ORM mapping with old datetime types
  - 🔧 Fix: Use DatePointType for better Clock integration

## 🎯 PRIORITY 2: Recommended Modern Patterns (Major)

### 🏗️ Service Configuration
- **Autoconfigure and Autowire**
  - ✅ Use: Modern service definitions with attributes
  - ❌ Avoid: Manual service configuration when autoconfigure works
  - 📍 Detection: Verbose YAML service definitions
  - 🔧 Fix: Leverage Symfony's autoconfiguration

### 🔐 Security Enhancements
- **Security Attributes**
  - ✅ Use: \`#[IsGranted]\`, \`#[Security]\` attributes
  - ❌ Avoid: Manual security checks in controllers
  - 📍 Detection: Manual \$this->denyAccessUnlessGranted() calls
  - 🔧 Fix: Use security attributes for cleaner code

### 📨 Event System
- **AsEventListener Attribute**
  - ✅ Use: \`#[AsEventListener]\` for event subscribers
  - ❌ Avoid: Manual event listener registration
  - 📍 Detection: Traditional EventSubscriberInterface usage
  - 🔧 Fix: Modernize with attributes

## 🎯 PRIORITY 3: Performance & DX Improvements (Minor)

### 🎛️ Controller Enhancements
- **MapRequestPayload & MapQueryString**
  - ✅ Use: Modern request parameter mapping
  - ❌ Avoid: Manual request parameter extraction
  - 📍 Detection: \$request->get(), \$request->query->get() patterns in changed files
  - 🔧 Fix: Use parameter mapping attributes

### 🧪 Testing Improvements
- **Modern Test Attributes**
  - ✅ Use: Latest PHPUnit and Symfony test attributes
  - ❌ Avoid: Deprecated testing patterns
  - 📍 Detection: Old test method naming, deprecated assertions
  - 🔧 Fix: Update to modern testing approach

### 📊 Validation Enhancements
- **Constraint Attributes**
  - ✅ Use: Validation attributes on DTOs/entities
  - ❌ Avoid: YAML/XML validation configuration where attributes work
  - 📍 Detection: External validation files for simple constraints
  - 🔧 Fix: Move to attribute-based validation

## 🔍 Detection Patterns for Changed Files Only

### Files to Scrutinize in Diff:
1. **Entities**: Look for old datetime types, missing modern mappings
2. **Controllers**: Check for manual parameter extraction, missing security attributes
3. **Services**: Verify modern dependency injection patterns
4. **Commands**: Ensure modern attribute-based configuration
5. **Event Listeners**: Check for attribute usage vs manual registration
6. **Tests**: Validate modern testing patterns

### Code Patterns to Flag in Changed Code:
\`\`\`php
// ❌ Flag these patterns in diff
new \DateTime()
new \DateTimeImmutable()
\$request->get('param')
manual service configuration for simple cases
extends EventSubscriberInterface without strong reason
\$this->denyAccessUnlessGranted() in controllers
datetime_immutable in Doctrine mappings

// ✅ Suggest these instead
DatePoint::createFromFormat()
#[MapRequestPayload]
#[IsGranted('ROLE_USER')]
#[AsEventListener]
DatePointType in Doctrine
\`\`\`
FEATURES

        log_success "Symfony features matrix generated -> $FEATURES_MATRIX"
    fi
}

generate_features_matrix

# === Step 2: Fetch and Generate Diff with Changed Files Analysis ===
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

# Extract changed files and analyze them
log_info "Analyzing changed files..."
git diff --name-only "$BASE_BRANCH...$FEATURE_BRANCH" > "$CHANGED_FILES_PATH"
CHANGED_FILES_COUNT=$(wc -l < "$CHANGED_FILES_PATH")
DIFF_SIZE=$(wc -l < "$DIFF_PATH")

log_success "Git diff generated ($DIFF_SIZE lines, $CHANGED_FILES_COUNT files) -> $DIFF_PATH"
log_verbose "Changed files saved to -> $CHANGED_FILES_PATH"

# === Step 3: Enhanced Context-Aware Project Analysis ===
scan_project_context() {
    log_info "Scanning global project context for architecture awareness..."
    
    # Global project analysis for context
    TOTAL_PHP_FILES=$(find src tests -name "*.php" 2>/dev/null | wc -l)
    DATEPOINT_USAGE=$(find src -name "*.php" -exec grep -l "DatePoint" {} \; 2>/dev/null | wc -l)
    DATETIME_USAGE=$(find src -name "*.php" -exec grep -l "DateTime" {} \; 2>/dev/null | wc -l)
    SECURITY_ATTRIBUTES=$(find src -name "*.php" -exec grep -l "#\[IsGranted\]" {} \; 2>/dev/null | wc -l)
    EVENT_ATTRIBUTES=$(find src -name "*.php" -exec grep -l "#\[AsEventListener\]" {} \; 2>/dev/null | wc -l)
    
    cat > "$CONTEXT_PATH" << CONTEXT
# Global Project Context Analysis

## Project Architecture Overview
- **Total PHP Files**: $TOTAL_PHP_FILES
- **Changed Files in Diff**: $CHANGED_FILES_COUNT
- **Coverage**: $(echo "scale=2; $CHANGED_FILES_COUNT * 100 / $TOTAL_PHP_FILES" | bc 2>/dev/null || echo "N/A")% of codebase affected

## Modern Symfony Features Adoption (Global)
- **DatePoint Usage**: $DATEPOINT_USAGE files (✅ Modern)
- **DateTime Usage**: $DATETIME_USAGE files (⚠️ Legacy - should migrate to DatePoint)
- **Security Attributes**: $SECURITY_ATTRIBUTES files (✅ Modern)
- **Event Listener Attributes**: $EVENT_ATTRIBUTES files (✅ Modern)

## Project Structure
\`\`\`
$(find src tests -type f -name "*.php" 2>/dev/null | head -20 | sort)
$(if [ $(find src tests -type f -name "*.php" 2>/dev/null | wc -l) -gt 20 ]; then echo "... and $(( $(find src tests -type f -name "*.php" 2>/dev/null | wc -l) - 20 )) more files"; fi)
\`\`\`

## Symfony Version Detection
$(if [ -f "composer.json" ]; then
    SYMFONY_VERSION_DETECTED=$(grep -o '"symfony/framework-bundle": "[^"]*"' composer.json 2>/dev/null || echo "Not detected")
    echo "**Detected Symfony Version**: $SYMFONY_VERSION_DETECTED"
    echo "**Target Review Version**: $SYMFONY_VERSION"
fi)

## Dependencies Analysis (composer.json)
$(if [ -f "composer.json" ]; then
    echo "\`\`\`json"
    jq '.require + .["require-dev"] // {}' composer.json 2>/dev/null || cat composer.json | grep -A 50 '"require"'
    echo "\`\`\`"
else
    echo "No composer.json found"
fi)

## Architecture Patterns (Global Context)
### Service Layer Pattern Usage
$(find src -path "*/Service/*" -name "*.php" 2>/dev/null | wc -l) service classes found
### Repository Pattern Usage  
$(find src -path "*/Repository/*" -name "*.php" 2>/dev/null | wc -l) repository classes found
### Entity Pattern Usage
$(find src -path "*/Entity/*" -name "*.php" 2>/dev/null | wc -l) entity classes found
### Controller Pattern Usage
$(find src -path "*/Controller/*" -name "*.php" 2>/dev/null | wc -l) controller classes found

## Legacy Pattern Detection (Global Awareness)
$(echo "### Potential Legacy Patterns in Project:")
$(find src -name "*.php" -exec grep -l "new.*DateTime" {} \; 2>/dev/null | wc -l) files with DateTime instances
$(find src -name "*.php" -exec grep -l "denyAccessUnlessGranted" {} \; 2>/dev/null | wc -l) files with manual security checks

## Integration Points Analysis
### Database Integration
$(if [ -d "src/Entity" ]; then
    echo "- Entities: $(find src/Entity -name "*.php" | wc -l) entity classes"
    echo "- Datetime fields: $(find src/Entity -name "*.php" -exec grep -l "datetime" {} \; 2>/dev/null | wc -l) entities with datetime"
fi)

### External Service Integration
$(if [ -f "composer.json" ]; then
    echo "- HTTP Client: $(grep -c "symfony/http-client" composer.json 2>/dev/null || echo "0") references"
    echo "- Mailer: $(grep -c "symfony/mailer" composer.json 2>/dev/null || echo "0") references"
    echo "- Messenger: $(grep -c "symfony/messenger" composer.json 2>/dev/null || echo "0") references"
fi)

## Testing Infrastructure
$(if [ -d "tests" ]; then
    echo "- Test files: $(find tests -name "*.php" | wc -l)"
    echo "- Unit tests: $(find tests -path "*/Unit/*" -name "*.php" 2>/dev/null | wc -l)"
    echo "- Integration tests: $(find tests -path "*/Integration/*" -name "*.php" 2>/dev/null | wc -l)"
    echo "- Functional tests: $(find tests -path "*/Functional/*" -name "*.php" 2>/dev/null | wc -l)"
fi)
CONTEXT

    log_success "Global project context analyzed -> $CONTEXT_PATH"
}

# === Analyze Diff Context ===
analyze_diff_context() {
    log_info "Analyzing diff-specific context and integration points..."
    
    cat > "$DIFF_CONTEXT_PATH" << DIFF_CONTEXT
# Diff-Specific Context Analysis

## Changed Files Analysis ($CHANGED_FILES_COUNT files)
\`\`\`
$(cat "$CHANGED_FILES_PATH")
\`\`\`

## File Type Distribution
$(echo "### Changed File Categories:")
$(grep -c "Controller" "$CHANGED_FILES_PATH" 2>/dev/null || echo "0") Controllers
$(grep -c "Entity" "$CHANGED_FILES_PATH" 2>/dev/null || echo "0") Entities  
$(grep -c "Service" "$CHANGED_FILES_PATH" 2>/dev/null || echo "0") Services
$(grep -c "Repository" "$CHANGED_FILES_PATH" 2>/dev/null || echo "0") Repositories
$(grep -c "Command" "$CHANGED_FILES_PATH" 2>/dev/null || echo "0") Commands
$(grep -c "EventListener\|EventSubscriber" "$CHANGED_FILES_PATH" 2>/dev/null || echo "0") Event Handlers
$(grep -c "Test" "$CHANGED_FILES_PATH" 2>/dev/null || echo "0") Tests
$(grep -c "config\|\.yaml\|\.yml" "$CHANGED_FILES_PATH" 2>/dev/null || echo "0") Configuration files

## Integration Impact Analysis
### Dependencies of Changed Files
$(while IFS= read -r file; do
    if [[ -f "$file" && "$file" == *.php ]]; then
        echo "#### $file"
        # Extract use statements to understand dependencies
        grep "^use " "$file" 2>/dev/null | head -5 | sed 's/^/- /' || echo "- No use statements found"
        echo ""
    fi
done < "$CHANGED_FILES_PATH")

## Modern Feature Opportunities in Changed Files
$(while IFS= read -r file; do
    if [[ -f "$file" && "$file" == *.php ]]; then
        echo "### $file - Modernization Opportunities"
        
        # Check for DateTime usage
        if grep -q "DateTime" "$file" 2>/dev/null; then
            echo "- ⚠️ DateTime usage found - consider DatePoint migration"
        fi
        
        # Check for manual security
        if grep -q "denyAccessUnlessGranted\|isGranted" "$file" 2>/dev/null; then
            echo "- ⚠️ Manual security checks - consider #[IsGranted] attributes"
        fi
        
        # Check for request parameter extraction
        if grep -q "\$request->get\|\$request->query->get" "$file" 2>/dev/null; then
            echo "- ⚠️ Manual parameter extraction - consider #[MapRequestPayload]"
        fi
        
        # Check for event subscribers
        if grep -q "EventSubscriberInterface" "$file" 2>/dev/null; then
            echo "- ⚠️ Traditional event subscriber - consider #[AsEventListener]"
        fi
        
        echo ""
    fi
done < "$CHANGED_FILES_PATH")

## Architecture Integration Points
### Service Layer Integration
$(while IFS= read -r file; do
    if [[ "$file" == *Service* && -f "$file" ]]; then
        echo "- $file: $(grep -c "public function" "$file" 2>/dev/null || echo "0") public methods"
    fi
done < "$CHANGED_FILES_PATH")

### Controller Layer Integration
$(while IFS= read -r file; do
    if [[ "$file" == *Controller* && -f "$file" ]]; then
        echo "- $file: $(grep -c "public function.*Action\|#\[Route\]" "$file" 2>/dev/null || echo "0") endpoints"
    fi
done < "$CHANGED_FILES_PATH")

### Data Layer Integration
$(while IFS= read -r file; do
    if [[ "$file" == *Entity* && -f "$file" ]]; then
        echo "- $file: $(grep -c "#\[ORM" "$file" 2>/dev/null || echo "0") ORM annotations/attributes"
    fi
done < "$CHANGED_FILES_PATH")

## Testing Impact
### Test Coverage for Changed Files
$(while IFS= read -r file; do
    if [[ "$file" == *.php && "$file" != *Test* ]]; then
        # Look for corresponding test file
        test_file=$(echo "$file" | sed 's|src/|tests/|' | sed 's|\.php|Test.php|')
        if [[ -f "$test_file" ]]; then
            echo "✅ $file -> $test_file"
        else
            echo "⚠️ $file -> No test file found"
        fi
    fi
done < "$CHANGED_FILES_PATH")
DIFF_CONTEXT

    log_success "Diff-specific context analyzed -> $DIFF_CONTEXT_PATH"
}

if $SCAN_CONTEXT; then
    scan_project_context
    analyze_diff_context
fi

# === Step 4: Generate Context-Aware Review Prompt ===
log_info "Generating context-aware code review prompt..."

cat > "$REVIEW_PROMPT" << PROMPT
# 🔍 Context-Aware Symfony Code Review - Latest Features Priority

## 📋 Review Context
- **Feature Branch:** \`$FEATURE_BRANCH\`
- **Base Branch:** \`$BASE_BRANCH\`
- **Target Symfony Version:** $SYMFONY_VERSION ⭐
- **PHP Version:** $PHP_VERSION
- **Lines Changed:** $DIFF_SIZE
- **Files Changed:** $CHANGED_FILES_COUNT
- **Latest Features Priority:** $(if $PRIORITIZE_LATEST; then echo "✅ ENABLED"; else echo "❌ DISABLED"; fi)

---

## 🚨 **CRITICAL: CONTEXT-AWARE ANALYSIS APPROACH**

**You are conducting a CONTEXT-AWARE code review with these MANDATORY principles:**

### 🎯 **ANALYSIS SCOPE - STRICTLY ENFORCE**
1. **ONLY REVIEW CHANGES**: Analyze ONLY the code changes in the git diff
2. **USE GLOBAL CONTEXT**: Leverage project context to make informed architectural decisions
3. **INTEGRATION FOCUS**: Ensure changes integrate well with existing codebase patterns
4. **NO OUTSIDE SUGGESTIONS**: Do NOT suggest changes to files not in the diff

### 🔍 **CONTEXT-AWARE METHODOLOGY**
- **Changed Files Analysis**: Focus review on the $(echo $CHANGED_FILES_COUNT) changed files
- **Architecture Harmony**: Ensure changes align with existing project patterns
- **Integration Points**: Verify proper integration with unchanged codebase
- **Modern Feature Adoption**: Prioritize Symfony 7.3+ features in new/changed code

---

## 🏗️ **GLOBAL PROJECT CONTEXT** (For Reference Only)

$(if $SCAN_CONTEXT && [ -f "$CONTEXT_PATH" ]; then
    cat "$CONTEXT_PATH"
    echo ""
fi)

---

## 🔍 **DIFF-SPECIFIC CONTEXT** (Primary Analysis Target)

$(if $SCAN_CONTEXT && [ -f "$DIFF_CONTEXT_PATH" ]; then
    cat "$DIFF_CONTEXT_PATH"
    echo ""
fi)

---

## 🚨 **CRITICAL REVIEW CRITERIA FOR CHANGED CODE ONLY**

$(if $PRIORITIZE_LATEST && [ -f "$FEATURES_MATRIX" ]; then
    cat "$FEATURES_MATRIX"
    echo ""
fi)

### 📊 **CONTEXT-AWARE SEVERITY CLASSIFICATION**

- **🚨 CRITICAL**: Changed code uses deprecated/legacy patterns when modern alternatives exist
- **⚠️ MAJOR**: Changed code misses opportunities to use Symfony 7.3+ features or breaks architectural consistency
- **💡 MINOR**: Changed code could be optimized or better integrated with existing patterns

### 🔍 **REVIEW AREAS (Context-Aware Priority Order)**

#### 1. 🏗️ **Architectural Integration** (HIGHEST PRIORITY)
- **Consistency**: Changes align with existing architecture patterns
- **Integration**: Proper integration with unchanged codebase components
- **Service Interaction**: Changed services properly interact with existing ones
- **Data Flow**: Changes maintain proper data flow patterns

#### 2. 🆕 **Modern Symfony Features in Changes** (HIGH PRIORITY)
- **DatePoint Integration**: New datetime handling uses DatePoint
- **Security Attributes**: New controllers use modern security attributes
- **Parameter Mapping**: New request handling uses modern mapping
- **Event System**: New event handling uses attributes

#### 3. 🔧 **Code Quality in Changes** (MEDIUM PRIORITY)
- **SOLID Principles**: Changed code follows SOLID principles
- **Type Safety**: New code uses proper typing
- **Error Handling**: Appropriate exception handling in changes
- **Performance**: Changed code doesn't introduce performance issues

#### 4. 🧪 **Testing Integration** (MEDIUM PRIORITY)
- **Test Coverage**: Changes have appropriate test coverage
- **Test Integration**: Tests integrate with existing test patterns
- **Mock Compatibility**: New mocks work with existing test infrastructure

---

## 📁 **GIT DIFF ANALYSIS** (PRIMARY FOCUS)

\`\`\`diff
$(cat "$DIFF_PATH")
\`\`\`

---

## 🎯 **MANDATORY Context-Aware Review Format**

### 🔍 **Executive Summary**
- **Context Integration Score**: X/10 (how well changes integrate with existing codebase)
- **Modern Feature Adoption**: X/10 (Symfony 7.3+ feature usage in changes)
- **Architectural Consistency**: X/10 (alignment with project patterns)
- **Overall Assessment**: [Brief overview focused on integration and modernization]

### ✅ **Well-Integrated Modern Changes**
- List specific examples where changes properly integrate with existing code while using modern features

### 🚨 **Integration & Legacy Issues** (CRITICAL)
- **Architecture Conflicts**: Changes that break existing patterns
- **Legacy Pattern Introduction**: New code using outdated approaches
- **Integration Problems**: Poor integration with existing components

### ⚠️ **Missed Integration Opportunities** (MAJOR)
- **Modern Feature Adoption**: Where Symfony 7.3+ features could be used in changes
- **Architecture Alignment**: Better integration with existing patterns
- **Service Integration**: Improved service layer interaction

### 💡 **Context-Aware Optimizations** (MINOR)
- Performance improvements considering existing codebase
- Better integration patterns
- Enhanced maintainability aligned with project structure

### 🏗️ **Architectural Integration Feedback**
- How changes affect overall architecture
- Integration with existing services and components
- Consistency with established patterns

### 🔧 **Context-Aware Recommendations** 
- Specific improvements for changed code considering project context
- Modern feature adoption that makes sense for this project
- Integration improvements

---

## 🚨 **DELIVERABLE: Context-Aware Review Comments**

**CRITICAL REQUIREMENT**: Every comment must:
1. Focus ONLY on changed code in the diff
2. Consider integration with existing project patterns
3. Prioritize Symfony 7.3+ features where applicable
4. Provide context-aware solutions

### 📝 **Comment Structure** (MANDATORY)

#### 🔍 Comment #[NUMBER]
**File:** \`path/to/changed/file.php\` (MUST be from changed files list)
**Line:** [EXACT_LINE_NUMBER_FROM_DIFF]  
**Severity:** 🚨 Critical / ⚠️ Major / 💡 Minor  
**Category:** [Integration|Modern Feature|Architecture|Legacy Pattern|Performance]
**Context Impact:** [How this affects integration with existing codebase]

**Issue in Changed Code:**
[Clear description focusing on the specific change and its integration impact]

**Context-Aware Resolution:**
[Solution considering existing project patterns and modern Symfony features]

**Integration Benefits:**
[How the proposed change improves integration with existing codebase]

**Code Example:**
\`\`\`php
// ❌ Current change (problematic)
[actual_changed_code_from_diff]

// ✅ Context-aware modern solution
[improved_code_considering_project_context]
\`\`\`

**Project Integration Notes:**
- [How this integrates with existing services/components]
- [Alignment with established patterns]
- [Modern feature benefits in this project context]

**Estimated Effort:** [Implementation time]
**Integration Risk:** [Low/Medium/High - risk to existing functionality]

---

## 🎯 **STRICT ANALYSIS BOUNDARIES**

### ✅ **DO ANALYZE:**
- Code changes in the git diff
- Integration points with existing unchanged code
- Modern feature opportunities in changed code
- Architectural consistency of changes

### ❌ **DO NOT ANALYZE:**
- Code conformity in unchanged files
- Existing code not touched by the diff
- Global refactoring suggestions outside the diff
- Changes to files not in the changed files list

### 🔍 **CONTEXT USAGE:**
- Use global project context to make informed decisions about changes
- Consider existing patterns when evaluating new code
- Ensure changes don't break established architecture
- Suggest modern features that fit the project context

---

## 📋 **Context-Aware Success Criteria**

The review MUST verify that changed code:
- [ ] Integrates seamlessly with existing architecture
- [ ] Uses Symfony 7.3+ features where applicable
- [ ] Maintains consistency with project patterns
- [ ] Doesn't introduce legacy patterns
- [ ] Properly interacts with unchanged components
- [ ] Follows established service/controller/entity patterns
- [ ] Maintains or improves overall code quality

**🚨 CRITICAL SUCCESS METRIC**: Changes must demonstrate context-aware modern Symfony development that enhances rather than disrupts the existing codebase.

💡 **Remember**: You're reviewing CHANGES with full awareness of the project context, not auditing the entire codebase. Focus on making the new/changed code the best it can be within the project's established patterns and modern Symfony practices.
PROMPT

log_success "Review prompt generated -> $REVIEW_PROMPT"

# === Step 5: Generate Configuration ===
log_info "Generating review configuration..."

cat > "$CONFIG_FILE" << CONFIG
{
  "review_session": {
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "feature_branch": "$FEATURE_BRANCH",
    "base_branch": "$BASE_BRANCH",
    "diff_lines": $DIFF_SIZE,
    "changed_files_count": $CHANGED_FILES_COUNT,
    "symfony_version": "$SYMFONY_VERSION",
    "php_version": "$PHP_VERSION",
    "context_scanned": $SCAN_CONTEXT,
    "prioritize_latest": $PRIORITIZE_LATEST,
    "ai_provider": "$AI_PROVIDER"
  },
  "files_generated": [
    "$DIFF_PATH",
    "$CHANGED_FILES_PATH",
    "$CONTEXT_PATH",
    "$DIFF_CONTEXT_PATH",
    "$REVIEW_PROMPT",
    "$REVIEW_OUTPUT",
    "$COMMENTS_DELIVERABLE",
    "$CONFIG_FILE",
    "$FEATURES_MATRIX"
  ]
}
CONFIG

log_success "Configuration generated -> $CONFIG_FILE"

# === Step 6: Execute AI Review ===
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
                    echo "Copilot review failed. Use the generated prompt manually." >> "$REVIEW_OUTPUT"
                fi
            else
                log_warning "GitHub CLI not found - install 'gh' for Copilot integration"
                echo "# GitHub Copilot Review Placeholder" > "$REVIEW_OUTPUT"
                echo "Use the generated prompt with GitHub Copilot manually." >> "$REVIEW_OUTPUT"
                generate_comments_deliverable
            fi
            ;;
        "claude")
            log_info "Claude AI integration requires API key setup"
            echo "# Claude AI Review Placeholder" > "$REVIEW_OUTPUT"
            echo "Use the generated prompt with Claude AI manually." >> "$REVIEW_OUTPUT"
            generate_comments_deliverable
            ;;
        "gpt")
            log_info "GPT integration requires OpenAI API setup"
            echo "# GPT Review Placeholder" > "$REVIEW_OUTPUT"
            echo "Use the generated prompt with ChatGPT manually." >> "$REVIEW_OUTPUT"
            generate_comments_deliverable
            ;;
        *)
            log_error "Invalid AI provider: $AI_PROVIDER"
            exit 1
            ;;
    esac
}

# === Generate Comments Deliverable ===
generate_comments_deliverable() {
    log_info "Generating review comments deliverable..."

    cat > "$COMMENTS_DELIVERABLE" << COMMENTS
# 📝 Context-Aware Review Comments Deliverable

## Review Metadata
- **Feature Branch:** \`$FEATURE_BRANCH\`
- **Base Branch:** \`$BASE_BRANCH\`
- **Timestamp:** $(date -u +"%Y-%m-%dT%H:%M:%SZ")
- **AI Provider:** $AI_PROVIDER
- **Changed Files:** $CHANGED_FILES_COUNT
- **Diff Lines:** $DIFF_SIZE

## Instructions
This file contains context-aware review comments generated based on the git diff. Each comment focuses on:
- Changed code only
- Integration with existing project patterns
- Symfony 7.3+ feature prioritization
- Actionable solutions with code examples

**To use:**
1. Review comments below
2. Apply suggested changes to the feature branch
3. Re-run the review script to verify improvements

## Comments
$(if [ -f "$REVIEW_OUTPUT" ]; then
    cat "$REVIEW_OUTPUT" | grep -A 20 "^#### 🔍 Comment #[0-9]*" 2>/dev/null || echo "No detailed comments generated by AI. Use $REVIEW_PROMPT manually."
else
    echo "No AI review output available. Use $REVIEW_PROMPT manually."
fi)

## Next Steps
- Address critical and major issues before merging
- Consider minor optimizations for better integration
- Re-run \`symfony-review $FEATURE_BRANCH --show\` to validate changes
- Ensure \`.vscode/\` is in \`.gitignore\` to keep review files local
COMMENTS

    log_success "Review comments deliverable generated -> $COMMENTS_DELIVERABLE"
}

execute_ai_review

# === Step 7: Display Results ===
if $SHOW_REVIEW && [ -f "$REVIEW_OUTPUT" ]; then
    log_info "Displaying review output..."
    echo ""
    echo "==================== REVIEW OUTPUT ===================="
    cat "$REVIEW_OUTPUT"
    echo "========================================================"
fi

# === Final Summary ===
echo ""
echo "🎉 Context-Aware Code Review Generation Complete!"
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
if $PRIORITIZE_LATEST; then
    echo "   🆕 Features Matrix:     $FEATURES_MATRIX"
fi
echo ""
echo "🔧 Next Steps:"
echo "   1. Review the prompt in $REVIEW_PROMPT"
echo "   2. Check comments in $COMMENTS_DELIVERABLE"
echo "   3. Apply suggested improvements to $FEATURE_BRANCH"
echo "   4. Re-run review to validate changes"
echo ""
echo "💡 Tip: Add '$VSCODE_DIR/' to your .gitignore to keep review files local"