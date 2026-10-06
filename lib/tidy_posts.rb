#!/usr/bin/env ruby
# frozen_string_literal: true

# =============================================================================
# tidy_posts.rb — Safe non-interactive repairs for Jekyll _posts markdown
# =============================================================================
#
# Applies the same PDF/conversion artifact repairs as tidy_bibtex does for
# .bib abstracts/titles, but on published-volume _posts/*.md:
#   - PDF wrap hyphens (same-line and cross-line YAML folds)
#   - PDF extraction ligatures (U+FB00–FB06 → ASCII)
#   - Over-escaped \textbackslash{} → \
#
# Does NOT rewrite YAML schema, author shapes, or titles. Read check_posts
# after running this (pmlint posts --fix does that).
#
# Usage:
#   ruby tidy_posts.rb -d VOLUME_DIR
#   ruby tidy_posts.rb -d VOLUME_DIR file1.md file2.md
#   ruby tidy_posts.rb -d VOLUME_DIR --changed [--base REF]
#
# Exit: 0 if no fatal errors (including when nothing needed fixing).

require 'optparse'
require 'open3'
require_relative 'pdf_wrap_hyphens'
require_relative 'text_field_artifacts'

class PostsTidy
  def initialize(options)
    @options = options
    @vol_dir = File.expand_path(options[:directory])
    @quiet = options[:quiet]
  end

  def run
    posts_dir = File.join(@vol_dir, '_posts')
    unless Dir.exist?(posts_dir)
      warn "ERROR: _posts/ not found under #{@vol_dir}"
      return 1
    end

    files = resolve_files(posts_dir)
    if files.empty?
      warn 'ERROR: No _posts/*.md files to tidy'
      return 1
    end

    totals = { files: 0, wrap: 0, lig: 0, tbs: 0 }
    files.each do |path|
      stats = tidy_file(path)
      next if stats.nil?

      totals[:files] += 1
      totals[:wrap] += stats[:wrap]
      totals[:lig] += stats[:lig]
      totals[:tbs] += stats[:tbs]
      unless @quiet
        rel = path.sub(%r{\A#{Regexp.escape(@vol_dir)}/?}, '')
        puts "  fixed #{rel} (wrap=#{stats[:wrap]} lig=#{stats[:lig]} tbs=#{stats[:tbs]})"
      end
    end

    unless @quiet
      puts "tidy_posts: files=#{totals[:files]} wrap=#{totals[:wrap]} " \
           "lig=#{totals[:lig]} tbs=#{totals[:tbs]}"
    end
    0
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
        warn "ERROR: git diff against #{base.inspect} failed"
        return []
      end
      paths = out.split("\n").map(&:strip).reject(&:empty?)
      paths = paths.select { |p| p.start_with?('_posts/') && p.end_with?('.md') }
      paths.map { |p| File.join(@vol_dir, p) }
    end
  end

  def tidy_file(path)
    return nil unless File.file?(path)

    raw = File.read(path, encoding: 'UTF-8')
    fixed, wrap_n = PdfWrapHyphens.fix(raw)

    lig_n = 0
    fixed = fixed.chars.map do |c|
      info = TextFieldArtifacts::PDF_EXTRACTION_LIGATURES[c.ord]
      if info
        lig_n += 1
        info[1]
      else
        c
      end
    end.join

    tbs_n = 0
    fixed = fixed.gsub(TextFieldArtifacts::TEXTBACKSLASH_RE) do
      tbs_n += 1
      '\\'
    end

    return nil if wrap_n.zero? && lig_n.zero? && tbs_n.zero?

    File.write(path, fixed)
    { wrap: wrap_n, lig: lig_n, tbs: tbs_n }
  end
end

options = {
  directory: nil,
  changed: false,
  base: nil,
  quiet: false,
  explicit_files: []
}

parser = OptionParser.new do |opts|
  opts.banner = 'Usage: tidy_posts.rb -d DIRECTORY [--changed] [--base REF] [--quiet] [FILES...]'
  opts.on('-d', '--directory DIR', 'Volume directory (contains _posts/)') { |d| options[:directory] = d }
  opts.on('--changed', 'Only posts changed vs --base / PMLINT_DIFF_BASE / HEAD^') { options[:changed] = true }
  opts.on('--base REF', 'Git ref for --changed') { |b| options[:base] = b }
  opts.on('--quiet', 'Suppress per-file and summary output') { options[:quiet] = true }
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

exit PostsTidy.new(options).run
