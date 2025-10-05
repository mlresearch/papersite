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
end
