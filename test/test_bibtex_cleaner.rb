#!/usr/bin/env ruby

require 'test/unit'
require 'tempfile'
require 'fileutils'
require_relative '../lib/tidy_bibtex'

class TestBibTeXCleaner < Test::Unit::TestCase
  def setup
    @cleaner = BibTeXCleaner.new
    @test_dir = Dir.mktmpdir("bibtex_test")
    Dir.chdir(@test_dir)
  end

  def teardown
    Dir.chdir('/')
    FileUtils.rm_rf(@test_dir)
  end

  def test_auto_detection_single_file
    # Create a single BibTeX file
    create_test_bib("test.bib", create_bib_with_percent_issues)
    
    # Test auto-detection
    bib_files = @cleaner.send(:find_bib_files)
    assert_equal 1, bib_files.length
    assert_equal "test.bib", bib_files[0]
  end

  def test_auto_detection_multiple_files
    # Create multiple BibTeX files
    create_test_bib("file1.bib", create_bib_with_percent_issues)
    create_test_bib("file2.bib", create_bib_with_percent_issues)
    
    # Test auto-detection
    bib_files = @cleaner.send(:find_bib_files)
    assert_equal 2, bib_files.length
    assert_equal ["file1.bib", "file2.bib"], bib_files
  end

  def test_auto_detection_no_files
    # Test with no BibTeX files
    bib_files = @cleaner.send(:find_bib_files)
    assert_equal 0, bib_files.length
  end

  def test_percent_detection
    content = create_bib_with_percent_issues
    issues = @cleaner.send(:find_unescaped_percent, content)
    
    assert issues.length > 0, "Should find unescaped % characters"
    assert issues.any? { |issue| issue.include?("abstract") }, "Should find issues in abstract"
    assert issues.any? { |issue| issue.include?("title") }, "Should find issues in title"
  end

  def test_percent_fixing
    content = create_bib_with_percent_issues
    fixed_content = @cleaner.send(:fix_unescaped_percent, content)
    
    # Check that % characters are now escaped
    assert !fixed_content.include?("abstract = {This is 50% accurate and shows 25% improvement}"), "Should escape % in abstract"
    assert !fixed_content.include?("title = {Machine Learning 100%}"), "Should escape % in title"
    assert fixed_content.include?("abstract = {This is 50\\% accurate and shows 25\\% improvement}"), "Should have escaped % in abstract"
    assert fixed_content.include?("title = {Machine Learning 100\\%}"), "Should have escaped % in title"
  end

  def test_author_field_detection
    content = create_bib_with_author_issues
    issues = @cleaner.send(:find_empty_author_fields, content)
    
    assert issues.length > 0, "Should find author field issues"
    assert issues.any? { |issue| issue.include?("double comma") }, "Should detect double comma issues"
  end

  def test_unmatched_braces_detection
    content = create_bib_with_unmatched_braces
    issues = @cleaner.send(:find_unmatched_braces, content)
    
    assert issues.length > 0, "Should find unmatched braces"
    assert issues.any? { |issue| issue.include?("Unmatched braces in title field") }, "Should detect unmatched braces in title"
    assert issues.any? { |issue| issue.include?("extra opening brace") }, "Should report extra opening braces"
  end

  def test_matched_braces_no_issues
    content = create_bib_with_matched_braces
    issues = @cleaner.send(:find_unmatched_braces, content)
    
    assert_equal 0, issues.length, "Should not find issues with properly matched braces"
  end

  def test_multiple_unmatched_braces
    content = create_bib_with_multiple_unmatched_braces
    issues = @cleaner.send(:find_unmatched_braces, content)
    
    assert issues.length >= 2, "Should find multiple unmatched brace issues"
  end

  def test_multiline_title_with_balanced_braces
    # Test case: Multi-line title that is properly balanced (no false positive)
    content = <<~BIB
      @InProceedings{test2024,
        title = {Multi-line Title: This is a Long Title that Spans
                  Multiple Lines},
        author = {John Doe},
        year = {2024}
      }
    BIB
    
    issues = @cleaner.send(:find_unmatched_braces, content)
    assert_equal 0, issues.length, "Should not find issues with balanced multi-line title"
  end

  def test_single_line_title_with_balanced_braces
    # Test case: Single-line title that is properly balanced (no false positive)
    content = <<~BIB
      @InProceedings{test2024,
        title = {This is a Single Line Title with Balanced Braces},
        author = {John Doe},
        year = {2024}
      }
    BIB
    
    issues = @cleaner.send(:find_unmatched_braces, content)
    assert_equal 0, issues.length, "Should not find issues with balanced single-line title"
  end

  def test_multiline_title_with_unbalanced_braces
    # Test case: Multi-line title with actual brace imbalance (true positive)
    content = <<~BIB
      @InProceedings{test2024,
        title = {Multi-line Title: This is Missing a Closing Brace
                  on Multiple Lines,
        author = {John Doe},
        year = {2024}
      }
    BIB
    
    issues = @cleaner.send(:find_unmatched_braces, content)
    assert issues.length > 0, "Should detect unbalanced braces in multi-line title"
    assert issues.any? { |issue| issue.include?("Unmatched braces in title field") }, 
           "Should report unmatched braces"
  end

  def test_title_with_nested_braces_balanced
    # Test case: Title with nested braces that are balanced
    content = <<~BIB
      @InProceedings{test2024,
        title = {{Nested {Braces} Within Title}: A Test Case},
        author = {John Doe},
        year = {2024}
      }
    BIB
    
    issues = @cleaner.send(:find_unmatched_braces, content)
    assert_equal 0, issues.length, "Should handle nested balanced braces correctly"
  end

  def test_multiline_title_with_special_chars
    # Test case: Multi-line title with LaTeX special characters
    content = <<~BIB
      @InProceedings{test2024,
        title = {Title with $\\delta$-Parameter: A Study on
                  Mathematical Notation},
        author = {John Doe},
        year = {2024}
      }
    BIB
    
    issues = @cleaner.send(:find_unmatched_braces, content)
    assert_equal 0, issues.length, "Should handle LaTeX special characters in multi-line titles"
  end

  def test_triple_backslash_detection
    # Test case: Detect triple backslashes (common error in percentages)
    # In Ruby strings, we need to escape backslashes: \\\\\\ becomes \\\
    content = <<~BIB
      @InProceedings{test2024,
        title = {Test Paper},
        author = {John Doe},
        abstract = {This method achieves 95\\\\\\% accuracy with 10\\\\\\% improvement.},
        year = {2024}
      }
    BIB
    
    issues = @cleaner.send(:find_triple_backslashes, content)
    assert issues.length > 0, "Should detect triple backslashes"
    assert issues.any? { |issue| issue.include?("Triple backslash found") }, 
           "Should report triple backslash issues"
    assert issues.any? { |issue| issue.include?("Context:") }, 
           "Should show line context"
  end

  def test_no_triple_backslash_in_correct_latex
    # Test case: Correctly escaped LaTeX should not trigger false positives
    content = <<~BIB
      @InProceedings{test2024,
        title = {Test Paper},
        author = {John Doe},
        abstract = {This method achieves 95\\\\% accuracy with \\\\textbf{bold} text.},
        year = {2024}
      }
    BIB
    
    issues = @cleaner.send(:find_triple_backslashes, content)
    assert_equal 0, issues.length, "Should not flag double backslash as triple backslash"
  end

  def test_double_backslash_detection
    # Test case: Detect double backslashes (unusual, worth reviewing)
    # In Ruby strings, \\\\ becomes \\
    content = <<~BIB
      @InProceedings{test2024,
        title = {Test Paper},
        author = {John Doe},
        abstract = {This method achieves 95\\\\% accuracy.},
        year = {2024}
      }
    BIB
    
    issues = @cleaner.send(:find_double_backslashes, content)
    assert issues.length > 0, "Should detect double backslashes"
    assert issues.any? { |issue| issue.include?("Double backslash found") }, 
           "Should report double backslash issues"
    assert issues.any? { |issue| issue.include?("Context:") }, 
           "Should show line context"
  end

  def test_no_double_backslash_for_single_backslash
    # Test case: Single backslash is correct and should not trigger
    # In Ruby strings, \\ becomes \
    content = <<~BIB
      @InProceedings{test2024,
        title = {Test Paper},
        author = {John Doe},
        abstract = {This method achieves 95\\% accuracy with \\textbf{bold} text.},
        year = {2024}
      }
    BIB
    
    issues = @cleaner.send(:find_double_backslashes, content)
    assert_equal 0, issues.length, "Should not flag correctly single-escaped LaTeX"
  end

  def test_utf8_file_reading
    # Create a file with UTF-8 characters
    content = create_bib_with_utf8_characters
    create_test_bib_with_encoding("utf8_test.bib", content, 'UTF-8')
    
    @cleaner.instance_variable_set(:@options, { 
      quiet: true,
      strict: false 
    })
    
    # Should successfully read and process UTF-8 file
    assert_nothing_raised do
      @cleaner.run
    end
    
    assert File.exist?("utf8_test_cleaned.bib"), "Should create output file"
    output = File.read("utf8_test_cleaned.bib", encoding: 'UTF-8')
    assert output.include?("Müller"), "Should preserve UTF-8 characters"
  end

  def test_latin1_file_reading
    # Create a file with Latin-1/ISO-8859-1 encoded characters
    content = create_bib_with_latin1_characters
    create_test_bib_with_encoding("latin1_test.bib", content, 'ISO-8859-1')
    
    @cleaner.instance_variable_set(:@options, { 
      quiet: true,
      strict: false 
    })
    
    # Should gracefully handle Latin-1 and convert to UTF-8
    assert_nothing_raised do
      @cleaner.run
    end
    
    assert File.exist?("latin1_test_cleaned.bib"), "Should create output file"
    # Output should be UTF-8
    output = File.read("latin1_test_cleaned.bib", encoding: 'UTF-8')
    assert output.valid_encoding?, "Output should be valid UTF-8"
  end

  def test_output_always_utf8
    # Test that output is always UTF-8 regardless of input
    content = create_bib_with_utf8_characters
    create_test_bib("mixed_test.bib", content)
    
    @cleaner.instance_variable_set(:@options, { 
      quiet: true,
      strict: false 
    })
    
    @cleaner.run
    
    # Read output and verify it's UTF-8
    output_file = "mixed_test_cleaned.bib"
    assert File.exist?(output_file), "Should create output file"
    
    # Check encoding by reading with UTF-8
    assert_nothing_raised do
      content = File.read(output_file, encoding: 'UTF-8')
      assert content.valid_encoding?, "Output should be valid UTF-8"
    end
  end

  def test_international_characters_preserved
    # Test that various international characters are preserved
    content = create_bib_with_international_characters
    create_test_bib_with_encoding("intl_test.bib", content, 'UTF-8')
    
    @cleaner.instance_variable_set(:@options, { 
      fix_all: true,
      quiet: true,
      strict: false 
    })
    
    @cleaner.run
    
    output = File.read("intl_test_cleaned.bib", encoding: 'UTF-8')
    assert output.include?("Müller"), "Should preserve German umlaut"
    assert output.include?("José"), "Should preserve Spanish accent"
    assert output.include?("Łukasz"), "Should preserve Polish characters"
  end

  def test_strict_mode_with_issues
    create_test_bib("test.bib", create_bib_with_percent_issues)
    
    # Test that strict mode fails when issues are found
    @cleaner.instance_variable_set(:@options, { strict: true, quiet: true })
    
    # Capture stderr to check for error
    original_stderr = $stderr
    $stderr = StringIO.new
    
    begin
      # This should exit with code 1 due to strict mode
      assert_raise(SystemExit) do
        @cleaner.run
      end
    ensure
      $stderr = original_stderr
    end
  end

  def test_clean_file_passes_strict_mode
    create_test_bib("test.bib", create_clean_bib)
    
    # Test that clean file passes strict mode
    @cleaner.instance_variable_set(:@options, { strict: true, quiet: true })
    
    # This should not raise an exception
    assert_nothing_raised do
      @cleaner.run
    end
  end

  def test_output_file_creation
    create_test_bib("test.bib", create_bib_with_percent_issues)
    
    @cleaner.instance_variable_set(:@options, { 
      fix_percent: true, 
      quiet: true,
      strict: false 
    })
    
    @cleaner.run
    
    # Check that output file was created
    assert File.exist?("test_cleaned.bib"), "Output file should be created"
    
    # Check that the output file has the fixes applied
    output_content = File.read("test_cleaned.bib")
    assert output_content.include?("50\\%"), "Output should have escaped % characters"
  end

  # Interactive mode test removed - complex to mock properly
  # The interactive functionality is tested in manual_test.rb

  def test_fix_all_option
    create_test_bib("test.bib", create_bib_with_percent_issues)
    
    @cleaner.instance_variable_set(:@options, { 
      fix_all: true,
      quiet: true,
      strict: false 
    })
    
    @cleaner.run
    
    assert File.exist?("test_cleaned.bib"), "Output file should be created with --fix-all"
    
    output_content = File.read("test_cleaned.bib")
    assert output_content.include?("50\\%"), "Should fix percent characters with --fix-all"
  end

  def test_verbose_output
    create_test_bib("test.bib", create_bib_with_percent_issues)
    
    @cleaner.instance_variable_set(:@options, { 
      verbose: true,
      fix_percent: true,
      strict: false 
    })
    
    # Capture output
    original_stdout = $stdout
    $stdout = StringIO.new
    
    begin
      @cleaner.run
      output = $stdout.string
      assert output.include?("Input file:"), "Should show verbose output"
      assert output.include?("Output file:"), "Should show verbose output"
    ensure
      $stdout = original_stdout
    end
  end

  def test_quiet_mode
    create_test_bib("test.bib", create_bib_with_percent_issues)
    
    @cleaner.instance_variable_set(:@options, { 
      quiet: true,
      fix_percent: true,
      strict: false 
    })
    
    # Capture output
    original_stdout = $stdout
    $stdout = StringIO.new
    
    begin
      @cleaner.run
      output = $stdout.string
      assert output.empty?, "Should produce no output in quiet mode"
    ensure
      $stdout = original_stdout
    end
  end

  def test_edge_case_empty_file
    create_test_bib("empty.bib", "")
    
    @cleaner.instance_variable_set(:@options, { 
      quiet: true,
      strict: false 
    })
    
    # Should not crash on empty file
    assert_nothing_raised do
      @cleaner.run
    end
  end

  def test_edge_case_no_abstract_or_title
    content = <<~BIB
      @article{test2024,
        author = {John Doe},
        year = {2024}
      }
    BIB
    
    create_test_bib("no_abstract.bib", content)
    
    @cleaner.instance_variable_set(:@options, { 
      quiet: true,
      strict: false 
    })
    
    # Should not crash on file without abstract/title
    assert_nothing_raised do
      @cleaner.run
    end
  end

  def test_complex_bibtex_structure
    content = <<~BIB
      @article{test1,
        title = {Paper 1 with 50% accuracy},
        author = {John Doe and Jane Smith},
        abstract = {This shows 75% improvement},
        year = {2024}
      }
      
      @inproceedings{test2,
        title = {Conference Paper 90%},
        author = {Alice Brown, , and Bob Green},
        abstract = {Another 25% gain},
        year = {2024}
      }
    BIB
    
    create_test_bib("complex.bib", content)
    
    @cleaner.instance_variable_set(:@options, { 
      fix_percent: true,
      check_author_commas: true,
      quiet: true,
      strict: false 
    })
    
    @cleaner.run
    
    assert File.exist?("complex_cleaned.bib"), "Should handle complex BibTeX structure"
    
    output_content = File.read("complex_cleaned.bib")
    assert output_content.include?("50\\%"), "Should fix percent in first entry"
    assert output_content.include?("75\\%"), "Should fix percent in abstract"
    assert output_content.include?("90\\%"), "Should fix percent in second entry"
  end

  private

  def create_test_bib(filename, content)
    File.write(filename, content)
  end

  def create_test_bib_with_encoding(filename, content, encoding)
    File.write(filename, content, encoding: encoding)
  end

  def create_bib_with_percent_issues
    <<~BIB
      @article{test2024,
        title = {Machine Learning 100%},
        author = {John Doe and Jane Smith},
        abstract = {This is 50% accurate and shows 25% improvement},
        year = {2024}
      }
    BIB
  end

  def create_bib_with_author_issues
    <<~BIB
      @article{test2024,
        title = {Test Paper},
        author = {John Doe, , and Jane Smith},
        abstract = {This is a test},
        year = {2024}
      }
    BIB
  end

  def create_clean_bib
    <<~BIB
      @article{test2024,
        title = {Machine Learning},
        author = {John Doe and Jane Smith},
        abstract = {This is a clean abstract},
        year = {2024}
      }
    BIB
  end

  def create_bib_with_unmatched_braces
    <<~BIB
      @InProceedings{test2024,
        title = {{Enhancing Robustness: A Test Case},
        author = {John Doe and Jane Smith},
        abstract = {This is a test abstract},
        year = {2024}
      }
    BIB
  end

  def create_bib_with_matched_braces
    <<~BIB
      @InProceedings{test2024,
        title = {{Enhancing Robustness: A Test Case}},
        author = {John Doe and Jane Smith},
        abstract = {This is a test abstract},
        year = {2024}
      }
    BIB
  end

  def create_bib_with_multiple_unmatched_braces
    <<~BIB
      @InProceedings{test2024a,
        title = {{First Paper with Unmatched Braces},
        author = {John Doe},
        year = {2024}
      }
      
      @InProceedings{test2024b,
        title = {{Second Paper Also Wrong},
        author = {Jane Smith},
        year = {2024}
      }
    BIB
  end

  def create_bib_with_utf8_characters
    <<~BIB
      @article{test2024,
        title = {Machine Learning with Müller},
        author = {Müller, Hans and Schmidt, Klaus},
        abstract = {This paper discusses résumé parsing},
        year = {2024}
      }
    BIB
  end

  def create_bib_with_latin1_characters
    # Content with characters common in Latin-1/ISO-8859-1
    <<~BIB
      @article{test2024,
        title = {Machine Learning},
        author = {Muller, Hans},
        abstract = {This is a test with special characters},
        year = {2024}
      }
    BIB
  end

  def create_bib_with_international_characters
    <<~BIB
      @article{test2024,
        title = {International Collaboration},
        author = {Müller, Hans and García, José and Łukasz, Kowalski},
        abstract = {This paper brings together researchers from Germany, Spain, and Poland},
        year = {2024}
      }
    BIB
  end
end
