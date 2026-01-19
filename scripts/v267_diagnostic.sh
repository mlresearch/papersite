#!/bin/bash

# Volume 267 Diagnostic Script
# Provides comprehensive diagnostics for large volume processing

set -e

VOLUME_NAME="v267"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAPERSITE_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in a git repository
check_git_repo() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        log_error "Not in a git repository"
        exit 1
    fi
    log_success "Git repository detected"
}

# Check current branch
check_branch() {
    local current_branch=$(git branch --show-current)
    log_info "Current branch: $current_branch"
    
    if [[ "$current_branch" != "gh-pages" && "$current_branch" != "main" ]]; then
        log_warning "Unexpected branch: $current_branch"
    fi
}

# Check repository state
check_repository_state() {
    log_info "Checking repository state..."
    
    # Check for uncommitted changes
    if ! git diff --quiet; then
        log_warning "Uncommitted changes detected"
        git status --porcelain
    else
        log_success "Repository is clean"
    fi
    
    # Check for untracked files
    local untracked=$(git ls-files --others --exclude-standard)
    if [[ -n "$untracked" ]]; then
        log_warning "Untracked files detected:"
        echo "$untracked"
    fi
}

# Check file counts
check_file_counts() {
    log_info "Checking file counts..."
    
    local pdf_count=$(find . -name "*.pdf" -type f | wc -l)
    local post_count=0
    local asset_count=0
    
    if [[ -d "_posts" ]]; then
        post_count=$(find _posts -name "*.md" -type f | wc -l)
    fi
    
    if [[ -d "assets" ]]; then
        asset_count=$(find assets -type f | wc -l)
    fi
    
    log_info "PDF files: $pdf_count"
    log_info "Post files: $post_count"
    log_info "Asset files: $asset_count"
    
    # Branch-specific validation
    local current_branch=$(git branch --show-current)
    if [[ "$current_branch" == "gh-pages" && $pdf_count -gt 0 ]]; then
        log_error "PDF files found in gh-pages branch"
        return 1
    fi
    
    if [[ "$current_branch" == "main" && $post_count -gt 0 ]]; then
        log_error "Post files found in main branch"
        return 1
    fi
    
    log_success "File counts validated"
}

# Check bandwidth usage
check_bandwidth() {
    log_info "Checking bandwidth usage..."
    
    # Check repository size
    local repo_size=$(du -sh .git | cut -f1)
    log_info "Repository size: $repo_size"
    
    # Check for large files
    local large_files=$(find . -type f -size +10M | head -10)
    if [[ -n "$large_files" ]]; then
        log_warning "Large files detected:"
        echo "$large_files"
    fi
    
    # Check git status
    local status_lines=$(git status --porcelain | wc -l)
    log_info "Modified files: $status_lines"
}

# Run comprehensive diagnostics
run_diagnostics() {
    local phase="$1"
    
    log_info "=== V267 DIAGNOSTIC REPORT - $phase ==="
    log_info "Timestamp: $(date)"
    log_info "Directory: $(pwd)"
    
    check_git_repo
    check_branch
    check_repository_state
    check_file_counts
    check_bandwidth
    
    log_info "=== END DIAGNOSTIC REPORT ==="
}

# Main execution
main() {
    local phase="${1:-general}"
    
    case "$phase" in
        "pre-check")
            run_diagnostics "PRE-PROCESSING"
            ;;
        "post-check")
            run_diagnostics "POST-PROCESSING"
            ;;
        "general")
            run_diagnostics "GENERAL"
            ;;
        *)
            log_error "Unknown phase: $phase"
            log_info "Usage: $0 [pre-check|post-check|general]"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"

