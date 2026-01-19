#!/bin/bash
# ==========================================================
# 🌿 Vue 3 Context-Aware Code Review Generator
# ==========================================================

set -euo pipefail

# === Paths ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # => script location
PROJECT_ROOT="$(pwd)"                                        # => current working directory (project root)
REVIEW_DIR="$PROJECT_ROOT/.vue-review"                      # => .vue-review in project root

mkdir -p "$REVIEW_DIR"

# === Configuration ===
CONFIG_FILE="$REVIEW_DIR/review-config.json"

DIFF_PATH="$REVIEW_DIR/vue.diff"
CHANGED_FILES_PATH="$REVIEW_DIR/changed-files.txt"
CONTEXT_PATH="$REVIEW_DIR/project-context.md"
DIFF_CONTEXT_PATH="$REVIEW_DIR/diff-context.md"
ESLINT_REPORT="$REVIEW_DIR/eslint-report.txt"
REVIEW_PROMPT="$REVIEW_DIR/vue-code-review-prompt.md"
REVIEW_OUTPUT="$REVIEW_DIR/review-output.md"
COMMENTS_DELIVERABLE="$REVIEW_DIR/review-comments-deliverable.md"
FEATURES_MATRIX="$REVIEW_DIR/review-features-matrix.md"
SUMMARY_FILE="$REVIEW_DIR/review-summary.md"

BASE_BRANCH="origin/main"
FEATURE_BRANCH=""
AI_PROVIDER="gpt"
SCAN_CONTEXT=true
VERBOSE=false

# === Colors ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# === Logging ===
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; exit 1; }

# === Usage ===
show_usage() {
cat <<USAGE
🎯 Vue 3 Code Review Generator (Premium Edition)

Usage:
  $0 <feature-branch> [options]

Options:
  --base BRANCH     Base branch to compare (default: origin/main)
  --ai PROVIDER     AI provider name (for reference only)
  --no-context      Skip context analysis
  --verbose         Enable verbose logging
  --help            Show help
USAGE
}

# === Parse arguments ===
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --base) BASE_BRANCH="$2"; shift 2 ;;
      --ai) AI_PROVIDER="$2"; shift 2 ;;
      --no-context) SCAN_CONTEXT=false; shift ;;
      --verbose) VERBOSE=true; shift ;;
      --help) show_usage; exit 0 ;;
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

# === Validation ===
validate_arguments() {
  if [ -z "$FEATURE_BRANCH" ]; then
    log_error "❌ Feature branch is required"
  fi
  if ! git rev-parse --verify "$FEATURE_BRANCH" &>/dev/null; then
    log_error "Branch '$FEATURE_BRANCH' not found"
  fi
  mkdir -p "$REVIEW_DIR"
}

# === Detect Vue version ===
detect_vue_version() {
  local version="unknown"
  if [ -f "$PROJECT_ROOT/package.json" ]; then
    version=$(grep -o '"vue":[^,]*' "$PROJECT_ROOT/package.json" | sed -E 's/.*"vue": *"([^"]+)".*/\1/')
  fi
  echo "${version:-unknown}"
}

# === Generate Git diff ===
generate_diff() {
  log_info "Generating Git diff..."
  git fetch origin &>/dev/null || true
  git diff "$BASE_BRANCH...$FEATURE_BRANCH" > "$DIFF_PATH"
  git diff --name-only "$BASE_BRANCH...$FEATURE_BRANCH" -- '*.vue' '*.ts' '*.js' '*.scss' '*.css' > "$CHANGED_FILES_PATH"
  log_success "Diff generated: $(wc -l < "$DIFF_PATH") lines"
}

# === Run ESLint ===
run_eslint_analysis() {
  log_info "Running ESLint..."
  if npm run lint --silent >"$ESLINT_REPORT" 2>&1; then
    log_success "ESLint passed successfully"
  else
    log_warning "ESLint found issues (see $ESLINT_REPORT)"
  fi
}

# === Generate global project context ===
generate_project_context() {
  log_info "Analyzing Vue 3 project context..."
  local vue_version=$(detect_vue_version)
  local vue_files=$(find src -name "*.vue" | wc -l || echo 0)
  local ts_files=$(find src -name "*.ts" | wc -l || echo 0)
  local js_files=$(find src -name "*.js" | wc -l || echo 0)

  cat > "$CONTEXT_PATH" <<EOF
# 🌿 Vue 3 Project Context

- **Vue Version**: $vue_version
- **Base Branch**: $BASE_BRANCH
- **Feature Branch**: $FEATURE_BRANCH
- **AI Provider**: $AI_PROVIDER
- **Files Count**:
  - Vue: $vue_files
  - TS: $ts_files
  - JS: $js_files

## 🧹 ESLint Summary (first 10 lines)
\`\`\`
$(head -n 10 "$ESLINT_REPORT" 2>/dev/null)
\`\`\`

## 📦 Key Dependencies
\`\`\`
$(grep -E '"(vite|vue-router|pinia|axios|typescript)"' package.json 2>/dev/null || echo "N/A")
\`\`\`
EOF
  log_success "Global context generated"
}

# === Generate diff context (per file) ===
generate_diff_context() {
  log_info "Creating per-file diff context..."
  echo "# 🧩 Diff Context per File" > "$DIFF_CONTEXT_PATH"
  while read -r file; do
    echo -e "\n## File: $file\n" >> "$DIFF_CONTEXT_PATH"
    echo '```diff' >> "$DIFF_CONTEXT_PATH"
    git diff "$BASE_BRANCH...$FEATURE_BRANCH" -- "$file" >> "$DIFF_CONTEXT_PATH"
    echo '```' >> "$DIFF_CONTEXT_PATH"
  done < "$CHANGED_FILES_PATH"
  log_success "Diff context generated"
}

# === Generate feature matrix ===
generate_features_matrix() {
  log_info "Building feature matrix..."
  echo "# 🧭 Features Matrix" > "$FEATURES_MATRIX"
  echo "" >> "$FEATURES_MATRIX"
  echo "| Component / File | Category | Description | Status |" >> "$FEATURES_MATRIX"
  echo "|:------------------|:----------|:-------------|:--------|" >> "$FEATURES_MATRIX"
  while read -r file; do
    category="Unknown"
    [[ "$file" == *"components/"* ]] && category="Component"
    [[ "$file" == *"views/"* ]] && category="View"
    [[ "$file" == *"store/"* ]] && category="Store"
    [[ "$file" == *"router/"* ]] && category="Routing"
    [[ "$file" == *"utils/"* ]] && category="Utility"
    echo "| $file | $category | Pending review | ⏳ |" >> "$FEATURES_MATRIX"
  done < "$CHANGED_FILES_PATH"
  log_success "Feature matrix generated"
}

# === Generate comments deliverable ===
generate_comments_deliverable() {
  log_info "Preparing comments deliverable template..."
  cat > "$COMMENTS_DELIVERABLE" <<EOF
# 💬 Vue 3 Code Review — Comments Deliverable

| File | Line | Type | Comment | Suggestion |
|:-----|:-----:|:------|:----------|:-------------|
| | | ⚠️ Issue | | |
| | | 💡 Improvement | | |
| | | 🚀 Optimization | | |
EOF
  log_success "Comments deliverable ready"
}

# === Generate review prompt ===
generate_review_prompt() {
  log_info "Building AI review prompt..."
  cat > "$REVIEW_PROMPT" <<EOF
# 🧠 Vue 3 Code Review Prompt (Premium)

You are a senior front-end reviewer.  
Analyze the provided Vue 3 project changes and identify potential issues.

Focus on:
- Composition API usage
- Reactivity pitfalls
- Props / emits correctness
- Performance, re-rendering
- ESLint violations
- Maintainability & DX

## Global Context
$(cat "$CONTEXT_PATH")

## Diff Context
$(cat "$DIFF_CONTEXT_PATH")
EOF
  log_success "Review prompt generated"
}

# === Generate summary ===
generate_summary() {
  local vue_version=$(detect_vue_version)
  local total_files=$(wc -l < "$CHANGED_FILES_PATH" || echo 0)
  local eslint_errors=$(grep -c "error" "$ESLINT_REPORT" || echo 0)

  cat > "$SUMMARY_FILE" <<EOF
# 📊 Vue 3 Review Summary

| Metric | Value |
|:-------|:------:|
| Vue Version | $vue_version |
| Base Branch | $BASE_BRANCH |
| Feature Branch | $FEATURE_BRANCH |
| Files Changed | $total_files |
| ESLint Errors | $eslint_errors |

## ⚠️ ESLint Errors (Top 5)
\`\`\`
$(grep "error" "$ESLINT_REPORT" | head -n 5 || echo "No errors found")
\`\`\`
EOF
  log_success "Review summary generated"
}

# === Main ===
main() {
  parse_arguments "$@"
  validate_arguments
  generate_diff
  run_eslint_analysis
  $SCAN_CONTEXT && generate_project_context
  generate_diff_context
  generate_features_matrix
  generate_comments_deliverable
  generate_review_prompt
  generate_summary

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
  echo "   🧾 ESLint Report:       $ESLINT_REPORT"
  echo "   🧭 Features Matrix:     $FEATURES_MATRIX"
  echo "   💬 Comments Deliverable: $COMMENTS_DELIVERABLE"
  echo "   📝 Review Prompt:       $REVIEW_PROMPT"
  echo "   📊 Review Summary:      $SUMMARY_FILE"
  echo "   ⚙️  Configuration:       $CONFIG_FILE"
  echo ""
  echo "🔧 Next Steps:"
  echo "   1. Review the prompt in $REVIEW_PROMPT"
  echo "   2. Paste it in ChatGPT / Copilot / Claude"
  echo "   3. Add findings to $COMMENTS_DELIVERABLE"
  echo "   4. Update status in $FEATURES_MATRIX"
  echo ""
  echo "💡 Tip: Add '$REVIEW_DIR/' to your .gitignore to keep review files local"
  echo ""
}

main "$@"
