---
id: "2025-10-05_github-action-bibtex-testing"
title: "GitHub Action for BibTeX Cleaner Script Testing"
status: "ready"
priority: "medium"
created: "2025-10-05"
last_updated: "2025-10-05"
owner: "Neil D. Lawrence"
dependencies: []
---

# Task: GitHub Action for BibTeX Cleaner Script Testing

## Description
Create a GitHub Action workflow that automatically runs the comprehensive test suite for the BibTeX cleaning script (`lib/tidy_bibtex.rb`) on every push and pull request. This will ensure that any changes to the script are validated before being merged.

This backlog item implements the testing framework requirements from **CIP-0002** by providing automated CI/CD integration for the testing framework established in **CIP-0003**. It addresses CIP-0002's goal of "integrating testing into development workflow" and CIP-0003's requirement for comprehensive testing of the BibTeX cleaning script.

## Acceptance Criteria
- [ ] GitHub Action workflow file created in `.github/workflows/`
- [ ] Workflow triggers on push to main/gh-pages branches
- [ ] Workflow triggers on pull requests to main/gh-pages branches
- [ ] Workflow runs the BibTeX cleaner test suite (`test/test_bibtex_cleaner.rb`)
- [ ] Workflow runs manual validation tests (`test/manual_test.rb`)
- [ ] Workflow fails if any tests fail
- [ ] Workflow provides clear output showing test results
- [ ] Workflow runs on Ubuntu latest with Ruby 3.0+
- [ ] Workflow installs required dependencies (test-unit gem)
- [ ] Workflow is documented in the test README

## Implementation Notes
The GitHub Action should:
1. **Checkout the repository** using `actions/checkout@v4`
2. **Set up Ruby environment** using `ruby/setup-ruby@v1` with Ruby 3.0+
3. **Install dependencies** (test-unit gem)
4. **Run automated test suite** using `ruby test/run_tests.rb`
5. **Run manual validation** using `ruby test/manual_test.rb`
6. **Report results** with clear pass/fail status

## Benefits
- **Automated validation** of BibTeX cleaner script changes
- **Early detection** of regressions or issues
- **Quality assurance** for the script before deployment
- **Consistent testing** across different environments
- **Documentation** of script reliability through CI

## CIP Integration
This backlog item directly addresses:
- **CIP-0002**: "Integrate testing into development workflow" - provides CI/CD integration
- **CIP-0002**: "Ensure tests can be run easily" - automated execution on every change
- **CIP-0003**: "Create comprehensive test suite" - validates the implemented test suite
- **CIP-0003**: "Test with sample BibTeX files" - ensures ongoing validation with real data

## Testing Strategy
- Test the workflow on a sample branch with changes to `lib/tidy_bibtex.rb`
- Verify that the workflow fails when tests are broken
- Verify that the workflow passes when tests are working
- Test both push and pull request triggers

## Related
- **CIP-0002**: Testing Framework and Conventions (establishes testing framework requirements)
- **CIP-0003**: BibTeX File Format Validation and Cleaning (script being tested)
- **Test Suite**: `test/test_bibtex_cleaner.rb`
- **Manual Tests**: `test/manual_test.rb`
- **Test Documentation**: `test/README.md`

## Progress Updates

### 2025-10-05
Task created. Ready for implementation of GitHub Action workflow for automated testing of the BibTeX cleaner script.
