#!/usr/bin/env ruby
# frozen_string_literal: true

# =============================================================================
# check_posts.rb — Validate Jekyll _posts YAML for published PMLR volumes
# =============================================================================
#
# Checks paper posts (FAQ correction path) for:
#   1. Valid YAML / Jekyll frontmatter fences
#   2. Frontmatter contract (layout, title, author, id, pdf, extras shape)
#   3. Within-post display vs bibtex_* / tex_title consistency (when present)
#   4. Non-printable C0/C1 control characters in string fields
#
# Usage:
#   ruby check_posts.rb -d VOLUME_DIR
#   ruby check_posts.rb -d VOLUME_DIR --changed [--base REF]
#   ruby check_posts.rb -d VOLUME_DIR file1.md file2.md
#
# Exit: 0 all pass; 1 one or more failures. Read-only.

require 'optparse'
require 'yaml'
require 'uri'
require 'open3'
require 'date'

module Colour
  def self.red(s)    "\e[31m#{s}\e[0m" end
  def self.green(s)  "\e[32m#{s}\e[0m" end
  def self.yellow(s) "\e[33m#{s}\e[0m" end
  def self.bold(s)   "\e[1m#{s}\e[0m"  end
  def self.cyan(s)   "\e[36m#{s}\e[0m" end
end

class PostsChecker
  PAPER_LAYOUTS = %w[inproceedings proceedings article].freeze
  REQUIRED_PAPER_KEYS = %w[layout title author id].freeze

  def initialize(options)
    @options = options
    @vol_dir = File.expand_path(options[:directory])
    @errors = []
    @warnings = []
    @ok = []
    @files_checked = 0
  end

  def run
    puts Colour.bold('=' * 60)
    puts Colour.bold('  PMLR _posts YAML check')
    puts Colour.bold('=' * 60)
    puts "  Directory: #{@vol_dir}"

    posts_dir = File.join(@vol_dir, '_posts')
    unless Dir.exist?(posts_dir)
      fatal "_posts/ not found under #{@vol_dir}"
    end

    files = resolve_files(posts_dir)
    if files.empty?
      fatal 'No _posts/*.md files to check'
    end
    puts "  Posts:     #{files.size} file(s)"
    puts

    files.each { |path| check_file(path) }

    print_summary
    @errors.empty? ? 0 : 1
  end

  private

  def resolve_files(posts_dir)
    if @options[:explicit_files] && !@options[:explicit_files].empty?
      return @options[:explicit_files].map { |f| File.expand_path(f, @vol_dir) }
    end

    if @options[:changed]
      return changed_post_files(posts_dir)
    end

    Dir.glob(File.join(posts_dir, '*.md')).sort
  end

  def changed_post_files(posts_dir)
    base = @options[:base] || ENV['PMLINT_DIFF_BASE'] || 'HEAD^'
    Dir.chdir(@vol_dir) do
      out, status = Open3.capture2('git', 'diff', '--name-only', '--diff-filter=ACMR', base, '--', '_posts/')
      unless status.success?
        fatal "git diff against #{base.inspect} failed (is this a git repo? set --base / PMLINT_DIFF_BASE)"
      end
      paths = out.split("\n").map(&:strip).reject(&:empty?)
      paths = paths.select { |p| p.start_with?('_posts/') && p.end_with?('.md') }
      paths.map { |p| File.join(@vol_dir, p) }
    end
  end

  def check_file(path)
    rel = path.sub(%r{\A#{Regexp.escape(@vol_dir)}/?}, '')
    section rel
    @files_checked += 1

    unless File.file?(path)
      error "  file not found: #{rel}"
      return
    end

    raw = File.read(path, encoding: 'UTF-8')
    check_raw_controls(raw, rel)

    fm_text, parse_err = extract_frontmatter(raw)
    if parse_err
      error "  #{parse_err}"
      return
    end

    data = load_yaml(fm_text, rel)
    return if data.nil?

    unless data.is_a?(Hash)
      error '  frontmatter did not parse to a mapping'
      return
    end

    check_schema(data, rel)
    check_consistency(data, rel)
    check_strings_for_controls(data, rel, [])
  end

  def extract_frontmatter(raw)
    lines = raw.lines
    unless lines.first&.strip == '---'
      return [nil, 'missing opening --- frontmatter fence']
    end

    close_idx = nil
    (1...lines.length).each do |i|
      if lines[i].strip == '---'
        close_idx = i
        break
      end
    end
    return [nil, 'missing closing --- frontmatter fence'] if close_idx.nil?

    body = lines[1...close_idx].join
    # Generator writes a citeproc comment as the last frontmatter line; keep it
    # out of YAML load by stripping full-line comments.
    body = body.lines.reject { |l| l.strip.start_with?('#') }.join
    [body, nil]
  end

  def load_yaml(text, rel)
    begin
      YAML.safe_load(
        text,
        permitted_classes: [Date, Time, Symbol],
        aliases: true
      )
    rescue ArgumentError
      # Psych API on older Ruby / YAML.safe_load signature
      YAML.safe_load(text, [Date, Time, Symbol], [], true)
    end
  rescue Psych::SyntaxError => e
    error "  invalid YAML: #{e.message}"
    nil
  rescue StandardError => e
    error "  YAML load error: #{e.class}: #{e.message}"
    nil
  end

  def check_schema(data, rel)
    layout = data['layout'].to_s
    if layout.empty?
      error '  missing required key: layout'
    elsif !PAPER_LAYOUTS.include?(layout)
      warn_msg "  unusual layout: #{layout.inspect} (expected one of #{PAPER_LAYOUTS.join(', ')})"
    else
      ok "  layout: #{layout}"
    end

    REQUIRED_PAPER_KEYS.each do |key|
      if blank?(data[key])
        error "  missing required key: #{key}"
      end
    end

    if PAPER_LAYOUTS.include?(layout) && layout != 'proceedings'
      if blank?(data['pdf'])
        error '  missing required key: pdf (paper layouts need a PDF URL)'
      elsif !urlish?(data['pdf'])
        error "  pdf is not a usable URL: #{data['pdf'].inspect}"
      else
        ok '  pdf present'
      end
    end

    author = data['author']
    unless author.nil?
      if !author.is_a?(Array) || author.empty?
        error '  author must be a non-empty list of {given, family} maps'
      else
        author.each_with_index do |a, i|
          unless a.is_a?(Hash)
            error "  author[#{i}] is not a mapping"
            next
          end
          if blank?(a['family'])
            error "  author[#{i}] missing family"
          end
        end
      end
    end

    if data.key?('extras')
      extras = data['extras']
      if extras.nil?
        ok '  extras: null/absent-equivalent'
      elsif !extras.is_a?(Array)
        error '  extras must be a list of {label, link} maps'
      else
        extras.each_with_index do |ex, i|
          unless ex.is_a?(Hash)
            error "  extras[#{i}] is not a mapping"
            next
          end
          if blank?(ex['label']) || blank?(ex['link'])
            error "  extras[#{i}] needs non-empty label and link"
          elsif !urlish?(ex['link'])
            error "  extras[#{i}].link is not a usable URL: #{ex['link'].inspect}"
          end
        end
        ok "  extras: #{extras.size} entr#{extras.size == 1 ? 'y' : 'ies'}" unless extras.empty?
      end
    end

    if data.key?('software') && !blank?(data['software']) && !urlish?(data['software'])
      error "  software is not a usable URL: #{data['software'].inspect}"
    end
  end

  def check_consistency(data, rel)
    bib = data['bibtex_author']
    authors = data['author']
    if bib.is_a?(String) && !bib.strip.empty? && authors.is_a?(Array)
      bib_norm = normalize_name_blob(bib)
      missing = []
      authors.each do |a|
        next unless a.is_a?(Hash)
        fam = a['family'].to_s
        next if fam.empty?
        missing << fam unless bib_norm.include?(normalize_token(fam))
      end
      if missing.empty?
        ok '  author families match bibtex_author'
      else
        error "  author family not found in bibtex_author: #{missing.join(', ')}"
      end
    end

    title = data['title']
    tex_title = data['tex_title']
    if title.is_a?(String) && tex_title.is_a?(String) && !tex_title.strip.empty?
      nt = normalize_title(title)
      ntt = normalize_title(tex_title)
      if nt == ntt
        ok '  title matches tex_title (normalised)'
      else
        error '  title and tex_title diverge after normalisation'
        error "    title:     #{nt[0, 80].inspect}"
        error "    tex_title: #{ntt[0, 80].inspect}"
      end
    end
  end

  def check_raw_controls(raw, rel)
    raw.each_char.with_index do |char, _|
      cp = char.ord
      next if cp == 0x09 || cp == 0x0A || cp == 0x0D
      if cp <= 0x1F || (0x7F..0x9F).cover?(cp)
        error "  non-printable character #{format('U+%04X', cp)} in file bytes"
        break
      end
    end
  end

  def check_strings_for_controls(node, rel, path)
    case node
    when String
      node.each_char do |char|
        cp = char.ord
        next if cp == 0x09 || cp == 0x0A || cp == 0x0D
        if cp <= 0x1F || (0x7F..0x9F).cover?(cp)
          loc = path.empty? ? 'value' : path.join('.')
          error "  non-printable #{format('U+%04X', cp)} in #{loc}"
          break
        end
      end
    when Array
      node.each_with_index { |v, i| check_strings_for_controls(v, rel, path + [i.to_s]) }
    when Hash
      node.each { |k, v| check_strings_for_controls(v, rel, path + [k.to_s]) }
    end
  end

  def normalize_token(s)
    t = expand_latex_text(s.to_s)
    # Compatibility for display UTF-8 vs BibTeX ASCII/LaTeX (ß ↔ ss, accents)
    t = t.unicode_normalize(:nfkd).gsub(/\p{Mn}/, '')
    t = t.gsub('ß', 'ss').gsub('ẞ', 'ss').gsub('ı', 'i').gsub('İ', 'i')
    t.downcase.gsub(/[^a-z0-9]/, '')
  end

  def normalize_name_blob(s)
    normalize_token(s)
  end

  def expand_latex_text(s)
    t = s.to_s.dup
    # Common BibTeX / detex forms before generic command unwrapping
    t.gsub!(/\{\\ss\}|\\ss\{\}|\\ss\b/, 'ss')
    t.gsub!(/\{\\i\}|\\i\{\}|\\i\b/, 'i')
    t.gsub!(/\\'\{\\i\}|\\'\{\i\}/, 'i')
    # \sqrt{T} and malformed detex \sqrtT (missing braces)
    t.gsub!(/\\sqrt\{([^{}]*)\}/, '\1')
    t.gsub!(/\\sqrt([A-Za-z])/, '\1')
    t.gsub!(/\{\\"([A-Za-z])\}|\\"([A-Za-z])/) { Regexp.last_match[1] || Regexp.last_match[2] }
    t.gsub!(/\{\\'([A-Za-z])\}|\\'([A-Za-z])/) { Regexp.last_match[1] || Regexp.last_match[2] }
    t.gsub!(/\{\\`([A-Za-z])\}|\\`([A-Za-z])/) { Regexp.last_match[1] || Regexp.last_match[2] }
    t.gsub!(/\{\\^([A-Za-z])\}|\\\^([A-Za-z])/) { Regexp.last_match[1] || Regexp.last_match[2] }
    t.gsub!(/\{\\~([A-Za-z])\}|\\~([A-Za-z])/) { Regexp.last_match[1] || Regexp.last_match[2] }
    3.times { t.gsub!(/\\[a-zA-Z]+\*?\s*\{([^{}]*)\}/, '\1') }
    t.gsub(/[{}]/, '')
  end

  def normalize_title(s)
    t = expand_latex_text(s.to_s)
    t = t.unicode_normalize(:nfkd).gsub(/\p{Mn}/, '')
    t = t.gsub('ı', 'i').gsub('İ', 'i')
    t = t.gsub('√', '') # display √T ↔ tex \sqrt{T} → T
    # detex sometimes leaves a bare sqrt{T} without the leading backslash
    t.gsub!(/\bsqrt\s*\{([^{}]*)\}/i, '\1')
    t.gsub!(/[\\$]/, '')
    t.gsub!(/\s+/, ' ')
    t.strip.downcase
  end

  def urlish?(value)
    s = value.to_s.strip
    return false if s.empty?
    uri = URI.parse(s)
    %w[http https].include?(uri.scheme) && !uri.host.to_s.empty?
  rescue URI::InvalidURIError
    false
  end

  def blank?(value)
    value.nil? || (value.respond_to?(:empty?) && value.empty?) ||
      (value.is_a?(String) && value.strip.empty?)
  end

  def section(title)
    puts Colour.cyan("  ── #{title}")
  end

  def ok(msg)
    puts Colour.green('  ✓') + " #{msg}"
    @ok << msg
  end

  def warn_msg(msg)
    puts Colour.yellow('  ⚠') + " #{msg}"
    @warnings << msg
  end

  def error(msg)
    puts Colour.red('  ✗') + " #{msg}"
    @errors << msg
  end

  def fatal(msg)
    puts Colour.red("FATAL: #{msg}")
    exit 1
  end

  def print_summary
    puts
    puts Colour.bold('=' * 60)
    puts Colour.bold('  Summary')
    puts Colour.bold('=' * 60)
    puts "  Files:    #{@files_checked}"
    puts Colour.green("  Passed:   #{@ok.size}")
    puts Colour.yellow("  Warnings: #{@warnings.size}")
    puts Colour.red("  Errors:   #{@errors.size}")
    puts
    if @errors.empty?
      puts Colour.green(Colour.bold('  ✓ _posts YAML checks passed.'))
    else
      puts Colour.red(Colour.bold("  ✗ #{@errors.size} issue(s) in _posts — fix before merge."))
    end
    puts
  end
end

# =============================================================================
# CLI
# =============================================================================

options = {
  directory: nil,
  changed: false,
  base: nil,
  explicit_files: []
}

parser = OptionParser.new do |opts|
  opts.banner = 'Usage: check_posts.rb -d DIRECTORY [--changed] [--base REF] [FILES...]'

  opts.on('-d', '--directory DIR', 'Volume directory (contains _posts/)') { |d| options[:directory] = d }
  opts.on('--changed', 'Only posts changed vs --base / PMLINT_DIFF_BASE / HEAD^') { options[:changed] = true }
  opts.on('--base REF', 'Git ref for --changed (default: PMLINT_DIFF_BASE or HEAD^)') { |b| options[:base] = b }
  opts.on('-h', '--help', 'Show this help') { puts opts; exit }
end

parser.parse!
options[:explicit_files] = ARGV.dup

unless options[:directory]
  warn 'ERROR: --directory is required'
  warn parser
  exit 1
end

unless Dir.exist?(options[:directory])
  warn "ERROR: Directory '#{options[:directory]}' does not exist"
  exit 1
end

exit PostsChecker.new(options).run
