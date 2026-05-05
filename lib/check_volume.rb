#!/usr/bin/env ruby

# =============================================================================
# check_volume.rb - Pre-publication validation for PMLR volumes
# =============================================================================
#
# Checks a volume directory is ready for publication:
#   1. @Proceedings entry has required fields with correct formatting
#   2. All BibTeX keys have matching PDF files in the root directory
#   3. No PDFs stranded in subdirectories
#   4. Supplementary files are in the root (not in subdirectories)
#   5. Author names are well-formed (Surname, Given format, no all-lowercase)
#   6. No double backslashes in any field
#   7. No escaped \$ \{ \} \_ in abstracts/titles
#   8. No non-ASCII characters in BibTeX keys
#
# Usage:
#   ruby check_volume.rb -v VOLUME -d DIRECTORY [-b BIBFILE] [--fix]

require 'optparse'
require 'set'

# =============================================================================
# Colours
# =============================================================================

module Colour
  def self.red(s)    "\e[31m#{s}\e[0m" end
  def self.green(s)  "\e[32m#{s}\e[0m" end
  def self.yellow(s) "\e[33m#{s}\e[0m" end
  def self.bold(s)   "\e[1m#{s}\e[0m"  end
  def self.cyan(s)   "\e[36m#{s}\e[0m" end
end

# =============================================================================
# Checker
# =============================================================================

class VolumeChecker

  REQUIRED_PROCEEDINGS_FIELDS = %w[published name shortname year editor start end address volume]
  SUPP_PATTERN = /-supp\.(pdf|zip|tar\.gz)$/i
  PDF_PATTERN  = /\.pdf$/i

  def initialize(options)
    @options   = options
    @vol_dir   = options[:directory]
    @volume    = options[:volume]
    @errors    = []
    @warnings  = []
    @ok        = []
  end

  # ---------------------------------------------------------------------------
  # Entry point
  # ---------------------------------------------------------------------------

  def run
    puts Colour.bold("=" * 60)
    puts Colour.bold("  PMLR Volume #{@volume} Pre-publication Check")
    puts Colour.bold("=" * 60)
    puts "  Directory: #{@vol_dir}"

    bib_path = find_bib_file
    unless bib_path
      fatal "No BibTeX file found in #{@vol_dir}"
    end
    puts "  BibTeX:    #{File.basename(bib_path)}"
    puts

    content = File.read(bib_path, encoding: 'utf-8')

    check_proceedings_entry(content)
    check_pdf_locations
    check_supp_locations
    check_pdf_bib_match(content)
    check_author_names(content)
    check_double_backslashes(content)
    check_escaped_chars(content)
    check_non_ascii_keys(content)

    print_summary
    @errors.empty? ? 0 : 1
  end

  # ---------------------------------------------------------------------------
  # Individual checks
  # ---------------------------------------------------------------------------

  def check_proceedings_entry(content)
    section "Proceedings entry"

    unless content =~ /@Proceedings\s*\{/i
      error "No @Proceedings entry found"
      return
    end

    # Extract the proceedings block (roughly)
    proc_match = content.match(/@Proceedings\s*\{[^,]+,(.*?)^\}/im)
    unless proc_match
      error "Could not parse @Proceedings block"
      return
    end
    block = proc_match[1]

    REQUIRED_PROCEEDINGS_FIELDS.each do |field|
      if block =~ /^\s*#{field}\s*=/i
        ok "  #{field} present"
      else
        error "  Missing required field: #{field}"
      end
    end

    # volume should be in braces
    if block =~ /volume\s*=\s*\{/i
      ok "  volume wrapped in braces"
    elsif block =~ /volume\s*=/i
      error "  volume value not wrapped in braces (e.g. volume = {304})"
    end

    # published date looks like a date
    if block =~ /published\s*=\s*\{(\d{4}-\d{2}-\d{2})\}/i
      ok "  published date format OK (#{$1})"
    elsif block =~ /published\s*=/i
      error "  published field present but not in YYYY-MM-DD format"
    end
  end

  def check_pdf_locations
    section "PDF file locations"

    root_pdfs = Dir.glob(File.join(@vol_dir, '*.pdf'))
                   .reject { |f| File.basename(f) =~ SUPP_PATTERN }
    ok "  #{root_pdfs.size} PDF(s) in root"

    subdirs_with_pdfs = []
    Dir.glob(File.join(@vol_dir, '*/')).each do |subdir|
      next if File.basename(subdir) == 'assets'
      next if File.basename(subdir) =~ /permissions?$/i
      pdfs = Dir.glob(File.join(subdir, '**', '*.pdf'))
                 .reject { |f| File.basename(f) =~ SUPP_PATTERN }
      subdirs_with_pdfs << [File.basename(subdir), pdfs.size] if pdfs.any?
    end

    if subdirs_with_pdfs.empty?
      ok "  No PDFs stranded in subdirectories"
    else
      subdirs_with_pdfs.each do |dir, count|
        error "  #{count} PDF(s) in subdirectory '#{dir}/' — move to root"
      end
    end
  end

  def check_supp_locations
    section "Supplementary file locations"

    root_supps = Dir.glob(File.join(@vol_dir, '*-supp.*'))
    if root_supps.any?
      ok "  #{root_supps.size} supplementary file(s) in root"
    else
      warn_msg "  No supplementary files found (OK if none submitted)"
    end

    subdirs_with_supps = []
    Dir.glob(File.join(@vol_dir, '*/')).each do |subdir|
      next if File.basename(subdir) == 'assets'
      supps = Dir.glob(File.join(subdir, '**', '*-supp.*'))
      subdirs_with_supps << [File.basename(subdir), supps.size] if supps.any?
    end

    if subdirs_with_supps.empty?
      ok "  No supplementary files stranded in subdirectories"
    else
      subdirs_with_supps.each do |dir, count|
        error "  #{count} supplementary file(s) in subdirectory '#{dir}/' — move to root"
      end
    end
  end

  def check_pdf_bib_match(content)
    section "BibTeX key / PDF file match"

    keys = content.scan(/@InProceedings\s*\{\s*([\w-]+)\s*,/i).flatten
    root_pdfs = Dir.glob(File.join(@vol_dir, '*.pdf'))
                   .map { |f| File.basename(f, '.pdf') }
                   .reject { |f| f =~ /-supp$/ }
                   .to_set

    missing_pdfs = keys.reject { |k| root_pdfs.include?(k) }
    extra_pdfs   = root_pdfs - keys.to_set

    ok "  #{keys.size} BibTeX entries, #{root_pdfs.size} root PDF(s)"

    if missing_pdfs.empty?
      ok "  All BibTeX keys have a matching PDF"
    else
      missing_pdfs.each { |k| error "  Missing PDF for key: #{k}" }
    end

    if extra_pdfs.empty?
      ok "  No extra PDFs without a BibTeX entry"
    else
      extra_pdfs.each { |p| warn_msg "  Extra PDF with no BibTeX entry: #{p}.pdf" }
    end
  end

  def check_author_names(content)
    section "Author name formatting"

    issues = []

    # Extract each entry key and its full author field value.
    # Author fields can span multiple lines; we collect everything between
    # 'author = {' and the matching closing brace.
    entry_positions = {}
    content.scan(/@\w+\s*\{\s*([\w-]+)\s*,/i) { entry_positions[$~.begin(0)] = $1 }

    content.scan(/author\s*=\s*\{/i) do
      start = $~.end(0)
      key   = entry_positions.select { |pos, _| pos <= $~.begin(0) }.max_by { |pos, _| pos }&.last || '?'

      # Walk forward counting braces to find the end of the field
      depth = 1
      i     = start
      while i < content.length && depth > 0
        case content[i]
        when '{' then depth += 1 unless i > 0 && content[i - 1] == '\\'
        when '}' then depth -= 1 unless i > 0 && content[i - 1] == '\\'
        end
        i += 1
      end
      author_val = content[start..i - 2].gsub(/\s+/, ' ').strip

      author_val.split(/\s+and\s+/i).each do |part|
        part = part.strip
        next if part.empty?
        next if part =~ /\A\{[^{}]*(\{[^{}]*\}[^{}]*)?\}\z/  # organisation name wrapped in braces

        if part !~ /,/
          issues << "  [#{key}] No comma in name: '#{part}'"
        elsif part[0] =~ /[a-z]/
          issues << "  [#{key}] Lowercase surname: '#{part}'"
        end
      end
    end

    if issues.empty?
      ok "  All author names appear well-formed"
    else
      issues.each { |i| error i }
    end
  end

  def check_double_backslashes(content)
    section "Double backslashes"

    lines_with_double = []
    entry_re = /(@\w+)\s*\{\s*([\w-]+)\s*,/i
    current_key = nil

    content.each_line.with_index(1) do |line, lineno|
      if (m = line.match(entry_re))
        current_key = m[2]
      end
      if line.include?('\\\\')
        lines_with_double << "  [#{current_key}] line #{lineno}: #{line.strip[0..80]}"
      end
    end

    if lines_with_double.empty?
      ok "  No double backslashes found"
    else
      lines_with_double.each { |l| error l }
    end
  end

  def check_escaped_chars(content)
    section "Escaped \\$, \\{, \\}, \\_ in abstracts/titles"

    issues = []
    current_key = nil
    in_field = false
    entry_re = /(@\w+)\s*\{\s*([\w-]+)\s*,/i

    content.each_line.with_index(1) do |line, lineno|
      if (m = line.match(entry_re))
        current_key = m[2]
      end

      in_field = true  if line =~ /^\s*(abstract|title)\s*=/i
      in_field = false if in_field && line.strip.end_with?('},')

      if in_field
        [['\\$', '\$'], ['\\{', '\{'], ['\\}', '\}'], ['\\_', '\_']].each do |pat, label|
          if line.include?(pat)
            issues << "  [#{current_key}] line #{lineno}: #{label} found — should be unescaped"
          end
        end
      end
    end

    if issues.empty?
      ok "  No escaped \\$, \\{, \\}, \\_ found in abstracts/titles"
    else
      issues.uniq.each { |i| error i }
    end
  end

  def check_non_ascii_keys(content)
    section "BibTeX key characters"

    bad_keys = content.scan(/@InProceedings\s*\{\s*([\w-]+[^\s,]*)\s*,/i)
                      .flatten
                      .select { |k| k =~ /[^\x00-\x7F]/ }

    if bad_keys.empty?
      ok "  All BibTeX keys are ASCII"
    else
      bad_keys.each { |k| error "  Non-ASCII character in key: '#{k}'" }
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def find_bib_file
    if @options[:bibfile]
      path = File.join(@vol_dir, @options[:bibfile])
      return File.exist?(path) ? path : nil
    end
    Dir.glob(File.join(@vol_dir, '*.bib'))
       .reject { |f| f =~ /_clean\.bib$/ }
       .first
  end

  def section(title)
    puts Colour.cyan("  ── #{title}")
  end

  def ok(msg)
    puts Colour.green("  ✓") + " #{msg}"
    @ok << msg
  end

  def warn_msg(msg)
    puts Colour.yellow("  ⚠") + " #{msg}"
    @warnings << msg
  end

  def error(msg)
    puts Colour.red("  ✗") + " #{msg}"
    @errors << msg
  end

  def fatal(msg)
    puts Colour.red("FATAL: #{msg}")
    exit 1
  end

  def print_summary
    puts
    puts Colour.bold("=" * 60)
    puts Colour.bold("  Summary")
    puts Colour.bold("=" * 60)
    puts Colour.green("  Passed:   #{@ok.size}")
    puts Colour.yellow("  Warnings: #{@warnings.size}")
    puts Colour.red("  Errors:   #{@errors.size}")
    puts

    if @errors.empty?
      puts Colour.green(Colour.bold("  ✓ Volume #{@volume} is ready for publication."))
    else
      puts Colour.red(Colour.bold("  ✗ #{@errors.size} issue(s) must be fixed before publication."))
    end
    puts
  end
end

# =============================================================================
# CLI
# =============================================================================

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: check_volume.rb -v VOLUME -d DIRECTORY [-b BIBFILE]"

  opts.on('-v', '--volume VOLUME', 'Volume number') { |v| options[:volume] = v }
  opts.on('-d', '--directory DIR', 'Path to volume directory') { |d| options[:directory] = d }
  opts.on('-b', '--bibfile FILE',  'BibTeX filename (auto-detected if omitted)') { |b| options[:bibfile] = b }
  opts.on('-h', '--help', 'Show this help') { puts opts; exit }
end.parse!

%i[volume directory].each do |req|
  unless options[req]
    warn "ERROR: --#{req} is required"
    exit 1
  end
end

unless Dir.exist?(options[:directory])
  warn "ERROR: Directory '#{options[:directory]}' does not exist"
  exit 1
end

exit VolumeChecker.new(options).run
