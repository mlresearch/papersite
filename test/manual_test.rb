#!/usr/bin/env ruby

require_relative '../lib/tidy_bibtex'

puts "BibTeX Cleaner Manual Test Suite"
puts "=" * 40

# Test 1: Auto-detection with single file
puts "\n1. Testing auto-detection with single file..."
Dir.mktmpdir("bibtex_manual_test") do |test_dir|
  Dir.chdir(test_dir) do
    # Create a test BibTeX file with issues
    File.write("test.bib", <<~BIB)
      @article{test2024,
        title = {Machine Learning 100%},
        author = {John Doe and Jane Smith},
        abstract = {This is 50% accurate and shows 25% improvement},
        year = {2024}
      }
    BIB
    
    puts "Created test.bib with unescaped % characters"
    
    # Test auto-detection
    cleaner = BibTeXCleaner.new
    bib_files = cleaner.send(:find_bib_files)
    puts "Found #{bib_files.length} BibTeX file(s): #{bib_files.join(', ')}"
    
    if bib_files.length == 1
      puts "✓ Auto-detection works correctly"
    else
      puts "✗ Auto-detection failed"
    end
  end
end

# Test 2: Issue detection
puts "\n2. Testing issue detection..."
test_content = <<~BIB
  @article{test2024,
    title = {Machine Learning 100%},
    author = {John Doe, , and Jane Smith},
    abstract = {This is 50% accurate},
    year = {2024}
  }
BIB

cleaner = BibTeXCleaner.new
percent_issues = cleaner.send(:find_unescaped_percent, test_content)
author_issues = cleaner.send(:find_empty_author_fields, test_content)

puts "Found #{percent_issues.length} percent issues"
puts "Found #{author_issues.length} author issues"

if percent_issues.length > 0 && author_issues.length > 0
  puts "✓ Issue detection works correctly"
else
  puts "✗ Issue detection failed"
end

# Test 3: Issue fixing
puts "\n3. Testing issue fixing..."
fixed_content = cleaner.send(:fix_unescaped_percent, test_content)

if fixed_content.include?("50\\%") && fixed_content.include?("100\\%")
  puts "✓ Issue fixing works correctly"
else
  puts "✗ Issue fixing failed"
end

# Test 4: End-to-end test
puts "\n4. Testing end-to-end functionality..."
Dir.mktmpdir("bibtex_e2e_test") do |test_dir|
  Dir.chdir(test_dir) do
    # Create test file
    File.write("test.bib", test_content)
    
    # Run the cleaner
    cleaner = BibTeXCleaner.new
    cleaner.instance_variable_set(:@options, { 
      fix_percent: true, 
      quiet: true,
      strict: false 
    })
    
    begin
      cleaner.run
      
      if File.exist?("test_cleaned.bib")
        puts "✓ Output file created successfully"
        
        # Check that fixes were applied
        output_content = File.read("test_cleaned.bib")
        if output_content.include?("50\\%") && output_content.include?("100\\%")
          puts "✓ Fixes applied correctly"
        else
          puts "✗ Fixes not applied correctly"
        end
      else
        puts "✗ Output file not created"
      end
    rescue => e
      puts "✗ End-to-end test failed: #{e.message}"
    end
  end
end

puts "\n" + "=" * 40
puts "Manual test suite completed!"
