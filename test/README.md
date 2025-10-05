# Testing Framework for PMLR Papersite

This directory contains the testing framework for the PMLR papersite project, implementing the requirements from CIP-0002.

## Framework Choice

We use Ruby's built-in **Test::Unit** framework for the following reasons:
- No external dependencies required
- Simple and straightforward syntax
- Built into Ruby standard library
- Easy to run and understand

## Test Structure

```
test/
├── README.md                 # This documentation
├── run_tests.rb             # Test runner script
├── manual_test.rb           # Manual validation script
└── test_bibtex_cleaner.rb   # Comprehensive test suite for BibTeX cleaner
```

## Running Tests

### Automated Test Suite
```bash
# Run all tests
ruby test/run_tests.rb

# Run specific test file
ruby test/test_bibtex_cleaner.rb
```

### Manual Testing
```bash
# Run manual validation
ruby test/manual_test.rb
```

## Test Conventions

### Naming
- Test files: `test_<component_name>.rb`
- Test methods: `test_<functionality_description>`
- Test data files: Created in temporary directories

### Organization
- Each test class inherits from `Test::Unit::TestCase`
- Setup and teardown methods for test isolation
- Private helper methods for test data creation
- Clear, descriptive test method names

### Coverage Areas
Our tests cover:
- **Auto-detection functionality** (single file, multiple files, no files)
- **Issue detection** (unescaped %, author field problems)
- **Issue fixing** (automatic and interactive modes)
- **Command-line options** (strict, verbose, quiet modes)
- **Edge cases** (empty files, malformed BibTeX)
- **End-to-end workflows** (complete processing pipelines)

## Test Data Management

Tests use temporary directories to ensure:
- No interference with actual project files
- Clean test environment for each test
- Automatic cleanup after test completion

## Integration with CI/CD

The test suite is designed to be easily integrated with any CI/CD system:
- Exit codes indicate test success/failure
- No external dependencies beyond Ruby standard library
- Clear, parseable output format

## Adding New Tests

When adding new functionality:

1. **Create test data** using the helper methods in existing tests
2. **Follow naming conventions** for test methods
3. **Test both success and failure cases**
4. **Include edge cases** and error conditions
5. **Update this documentation** if adding new test categories

## Example Test Structure

```ruby
def test_new_functionality
  # Setup test data
  create_test_bib("test.bib", test_content)
  
  # Configure options
  @cleaner.instance_variable_set(:@options, { 
    new_option: true,
    quiet: true 
  })
  
  # Run functionality
  @cleaner.run
  
  # Assert expected behavior
  assert File.exist?("expected_output.bib"), "Output should be created"
  assert output_content.include?("expected_result"), "Should contain expected result"
end
```

## Troubleshooting

### Common Issues
- **Permission errors**: Ensure test directories are writable
- **File not found**: Check that test data is created in setup
- **Output capture**: Use StringIO for testing output/input redirection

### Debug Mode
Add `puts` statements in test methods for debugging:
```ruby
def test_debug_example
  puts "Debug: Testing with content: #{test_content}"
  # ... test code ...
end
```

## References

- [Test::Unit Documentation](https://ruby-doc.org/stdlib-2.7.0/libdoc/test/unit/rdoc/Test/Unit.html)
- [CIP-0002: Testing Framework and Conventions](../cip/cip0002.md)
- [CIP-0003: BibTeX File Format Validation and Cleaning](../cip/cip0003.md)
