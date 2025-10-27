#!/usr/bin/env ruby

require 'optparse'
require 'yaml'

class BibTeXCleaner
  def initialize
    @options = {
      :strict => false,
      :verbose => false,
      :quiet => false,
      :interactive => false,
      :fix_percent => false,
      :fix_author_commas => false,
      :fix_all => false
    }
  end

  def parse_options
    parser = OptionParser.new do |parser|
      parser.banner = "Usage: tidy_bibtex.rb [INPUT OUTPUT] [options]"
      
      parser.on("--strict", "Strict mode - fail on any issues found") do
        @options[:strict] = true
      end
      
      parser.on("--verbose", "Verbose output") do
        @options[:verbose] = true
      end
      
      parser.on("--quiet", "Quiet mode") do
        @options[:quiet] = true
      end
      
      parser.on("--interactive", "Interactive mode for fixing issues") do
        @options[:interactive] = true
      end
      
      parser.on("--fix-percent", "Fix unescaped % characters in abstracts and titles") do
        @options[:fix_percent] = true
      end
      
      parser.on("--check-author-commas", "Check for empty author fields (double commas) - reports only") do
        @options[:check_author_commas] = true
      end
      
      parser.on("--fix-all", "Apply all automatic fixes") do
        @options[:fix_all] = true
      end
      
      parser.on("-h", "--help", "Show this help message") do
        puts parser
        exit
      end
    end

    begin
      parser.parse!
    rescue OptionParser::InvalidOption, OptionParser::MissingArgument => e
      STDERR.puts "Error: #{e.message}"
      STDERR.puts parser
      exit 1
    end
  end

  def run
    parse_options
    
    # Auto-detect single BibTeX file if no arguments provided
    if ARGV.length == 0
      bib_files = find_bib_files
      if bib_files.length == 0
        STDERR.puts "Error: No BibTeX files found in current directory"
        exit 1
      elsif bib_files.length > 1
        STDERR.puts "Error: Multiple BibTeX files found. Please specify which one to process:"
        bib_files.each { |f| STDERR.puts "  #{f}" }
        exit 1
      else
        input_file = bib_files[0]
        output_file = input_file.sub(/\.bib$/, '_cleaned.bib')
        puts "Auto-detected BibTeX file: #{input_file}" unless @options[:quiet]
        puts "Output file: #{output_file}" unless @options[:quiet]
      end
    elsif ARGV.length < 2
      STDERR.puts "Error: Input and output files required"
      STDERR.puts "Usage: tidy_bibtex.rb [INPUT OUTPUT] [options]"
      STDERR.puts "       tidy_bibtex.rb [options]  # Auto-detect single .bib file"
      exit 1
    else
      input_file = ARGV[0]
      output_file = ARGV[1]
    end
    
    unless File.exist?(input_file)
      STDERR.puts "Error: Input file '#{input_file}' not found"
      exit 1
    end
    
    puts "Input file: #{input_file}" unless @options[:quiet]
    puts "Output file: #{output_file}" unless @options[:quiet]
    
    # Try to read with UTF-8, fall back to other encodings if needed
    begin
      content = File.read(input_file, encoding: 'UTF-8')
    rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
      # If UTF-8 fails, try with binary mode and force UTF-8 encoding
      content = File.read(input_file, encoding: 'binary').force_encoding('UTF-8')
      unless content.valid_encoding?
        # If still invalid, try ISO-8859-1 (Latin-1) and convert to UTF-8
        content = File.read(input_file, encoding: 'ISO-8859-1:UTF-8')
      end
    end
    
    issues_found = []
    fixes_applied = []
    
    # Check for unescaped % characters in abstracts and titles
    if @options[:fix_percent] || @options[:fix_all]
      percent_issues = find_unescaped_percent(content)
      if percent_issues.any?
        issues_found.concat(percent_issues)
        if @options[:interactive]
          if ask_fix("Found #{percent_issues.length} unescaped % characters. Fix them?")
            content = fix_unescaped_percent(content)
            fixes_applied << "Fixed #{percent_issues.length} unescaped % characters"
          end
        else
          content = fix_unescaped_percent(content)
          fixes_applied << "Fixed #{percent_issues.length} unescaped % characters"
        end
      end
    else
      percent_issues = find_unescaped_percent(content)
      issues_found.concat(percent_issues)
    end
    
    # Check for empty author fields (double commas) - report only, don't fix
    if @options[:check_author_commas] || @options[:fix_all]
      comma_issues = find_empty_author_fields(content)
      if comma_issues.any?
        issues_found.concat(comma_issues)
        puts "Found #{comma_issues.length} empty author fields that need manual review:" unless @options[:quiet]
        comma_issues.each do |issue|
          puts "  - #{issue}" unless @options[:quiet]
        end
      end
    else
      comma_issues = find_empty_author_fields(content)
      issues_found.concat(comma_issues)
    end
    
    # Report issues found
    if issues_found.any?
      puts "\nIssues found:" unless @options[:quiet]
      issues_found.each do |issue|
        puts "  - #{issue}" unless @options[:quiet]
      end
      
      if @options[:strict] && fixes_applied.empty?
        STDERR.puts "\nError: Issues found in strict mode and no fixes applied"
        exit 1
      end
    end
    
    # Report fixes applied
    if fixes_applied.any?
      puts "\nFixes applied:" unless @options[:quiet]
      fixes_applied.each do |fix|
        puts "  - #{fix}" unless @options[:quiet]
      end
    end
    
    # Write cleaned file
    File.write(output_file, content, encoding: 'UTF-8')
    puts "Cleaned file written to #{output_file}" unless @options[:quiet]
    
    if issues_found.any? && fixes_applied.empty?
      puts "\nWarning: Issues found but no fixes applied. Use --fix-percent, --fix-author-commas, or --fix-all to apply fixes."
    end
  end

  private

  def find_unescaped_percent(content)
    issues = []
    lines = content.split("\n")
    
    lines.each_with_index do |line, index|
      # Look for % characters in abstract and title fields that aren't already escaped
      if line.match(/^\s*(abstract|title)\s*=\s*\{.*[^\\]%.*\}.*$/)
        # Count unescaped % characters
        unescaped_count = line.scan(/[^\\]%/).length
        if unescaped_count > 0
          issues << "Line #{index + 1}: #{unescaped_count} unescaped % character(s) in #{line.match(/^\s*(\w+)\s*=/)[1]} field"
        end
      end
    end
    
    issues
  end

  def fix_unescaped_percent(content)
    lines = content.split("\n")
    
    lines.map! do |line|
      if line.match(/^\s*(abstract|title)\s*=\s*\{.*[^\\]%.*\}.*$/)
        # Replace unescaped % with \% in abstract and title fields
        line.gsub(/([^\\])%/, '\1\\%')
      else
        line
      end
    end
    
    lines.join("\n")
  end

  def find_empty_author_fields(content)
    issues = []
    lines = content.split("\n")
    
    lines.each_with_index do |line, index|
      # Look for author fields with empty fields (double commas)
      if line.match(/^\s*author\s*=\s*\{.*,\s*,.*\}.*$/)
        issues << "Line #{index + 1}: Empty author field (double comma) in author list"
      end
    end
    
    issues
  end

  # Removed fix_empty_author_fields method - we don't auto-fix author issues

  def ask_fix(question)
    print "#{question} (y/n): "
    response = STDIN.gets.chomp.downcase
    response == 'y' || response == 'yes'
  end

  def find_bib_files
    bib_files = []
    Dir.glob("*.bib").each do |file|
      bib_files << file
    end
    bib_files.sort
  end
end

# Run the cleaner
if __FILE__ == $0
  cleaner = BibTeXCleaner.new
  cleaner.run
end
