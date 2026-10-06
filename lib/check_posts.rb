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
#   5. PDF / conversion artifacts in abstract, title, tex_title, bibtex_author
#      (wrap hyphens, \textbackslash, ligatures, escaped \$\{ \}, \\\\ ) —
#      same classes as check_volume on .bib abstracts/titles
#   6. Sectioned volumes: when _config.yml declares sections, every paper post
#      must have section matching a declared name exactly (site filter)
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
begin
  require 'bibtex'
rescue LoadError
  # Optional until bin/pmlint / CI installs bibtex-ruby; parse_bibtex_authors handles nil.
end
require_relative 'text_field_artifacts'

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
    @current_rel = nil
    @declared_sections = nil
    @section_counts = Hash.new(0)
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

    @declared_sections = load_declared_sections
    if @declared_sections
      puts "  Sections:  #{@declared_sections.join(' | ')}"
    end

    files = resolve_files(posts_dir)
    if files.empty?
      fatal 'No _posts/*.md files to check'
    end
    puts "  Posts:     #{files.size} file(s)"
    puts

    files.each { |path| check_file(path) }
    check_section_coverage(files.size)

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
    @current_rel = rel
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
    check_section_field(data, rel)
    check_consistency(data, rel)
    check_strings_for_controls(data, rel, [])
    check_text_field_artifacts(data, rel)
  end

  def load_declared_sections
    cfg_path = File.join(@vol_dir, '_config.yml')
    return nil unless File.file?(cfg_path)

    raw = File.read(cfg_path, encoding: 'UTF-8')
    cfg = begin
      YAML.safe_load(
        raw,
        permitted_classes: [Date, Time, Symbol],
        aliases: true
      )
    rescue ArgumentError
      YAML.safe_load(raw, [Date, Time, Symbol], [], true)
    end
    return nil unless cfg.is_a?(Hash)
    return nil unless cfg.key?('sections')

    secs = cfg['sections']
    return [] if secs.nil?

    case secs
    when Array
      secs.map do |s|
        if s.is_a?(Hash)
          (s['name'] || s[:name]).to_s.strip
        else
          s.to_s.strip
        end
      end.reject(&:empty?)
    when String
      secs.split('|').map { |p| p.split('=', 2).first.to_s.strip }.reject(&:empty?)
    else
      []
    end
  rescue StandardError => e
    warn_msg "  could not load _config.yml sections: #{e.message}"
    nil
  end

  def check_section_field(data, rel)
    sec = data['section']
    sec = sec.to_s.strip if sec

    if @declared_sections.nil?
      if sec && !sec.empty?
        warn_msg '  section present but _config.yml has no sections list ' \
                 '(cannot verify name match)'
      end
      return
    end

    if @declared_sections.empty?
      error '  _config.yml sections list is empty'
      return
    end

    if sec.nil? || sec.empty?
      error "  missing section (volume declares: #{@declared_sections.join(', ')})"
      return
    end

    unless @declared_sections.include?(sec)
      error "  section #{sec.inspect} does not match declared sections " \
            "(#{@declared_sections.join(', ')}) — exact match required or " \
            'the paper will not appear on the site'
      return
    end

    @section_counts[sec] += 1
    ok "  section: #{sec}"
  end

  # Empty declared sections hide whole TOC groups. Only assert coverage when
  # we scanned the full _posts tree (not --changed / explicit file lists).
  def check_section_coverage(_n_files)
    return if @declared_sections.nil? || @declared_sections.empty?
    return if @options[:changed]
    return if @options[:explicit_files] && !@options[:explicit_files].empty?

    @current_rel = nil
    puts
    puts Colour.cyan('  ── Section coverage')
    @declared_sections.each do |name|
      n = @section_counts[name]
      if n.zero?
        error "  Declared section #{name.inspect} has no papers — heading will be empty on the site"
      else
        ok "  #{name}: #{n} paper(s)"
      end
    end
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
          # Official mononym form: family: Name with empty/absent given
          # (BibTeX Name,,). Inverted given-only mononyms still parse, but warn
          # so correction PRs migrate toward the generator/FAQ shape.
          if blank?(a['family']) && blank?(a['given']) && blank?(a['literal'])
            error "  author[#{i}] missing family/given"
          elsif blank?(a['family']) && !blank?(a['given']) && blank?(a['literal'])
            warn_msg "  author[#{i}] mononym should use family: #{a['given']} " \
                     '(not given-only); bibtex_author form is Name,,'
          elsif !blank?(a['family']) && blank?(a['given']) && blank?(a['literal'])
            ok "  author[#{i}] mononym family-only"
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

    if data.key?('software') && !blank?(data['software']) && !software_ok?(data['software'])
      error "  software is not a usable URL: #{data['software'].inspect}"
    end
  end

  def check_consistency(data, rel)
    bib = data['bibtex_author']
    authors = data['author']
    if bib.is_a?(String) && !bib.strip.empty? && authors.is_a?(Array)
      check_author_bibtex_consistency(authors, bib)
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

  # Parse bibtex_author with bibtex-ruby and compare structured names to author[].
  # Catches Given/Family swaps that a family-substring check would miss (e.g. Lee
  # appearing inside "Ryan Lee T." while bibtex still has family Z.).
  def check_author_bibtex_consistency(authors, bib)
    parsed = parse_bibtex_authors(bib)
    if parsed.nil?
      error '  could not parse bibtex_author with BibTeX (install bibtex-ruby)'
      return
    end

    yaml_names = authors.select { |a| a.is_a?(Hash) }
    if yaml_names.length != parsed.length
      error "  author count #{yaml_names.length} != bibtex_author count #{parsed.length}"
      return
    end

    mismatches = []
    yaml_names.each_with_index do |a, i|
      y_fam = name_part(a, 'family')
      y_given = name_part(a, 'given')
      # literal: org names — compare against bibtex family/literal blob
      if !blank?(a['literal'])
        lit = normalize_token(a['literal'])
        b = parsed[i]
        b_blob = normalize_token([b['prefix'], b['family'], b['given']].compact.join(' '))
        mismatches << "##{i}: literal #{a['literal'].inspect}" unless lit == b_blob
        next
      end
      next if y_fam.empty? && y_given.empty?

      b_fam = name_part(parsed[i], 'family')
      b_given = name_part(parsed[i], 'given')

      # Warn-first mononym policy: given-only YAML vs family-only BibTeX (or
      # the reverse) already warns on author[]; treat the non-empty tokens as
      # matching so we do not fail twice for the same encoding quirk.
      y_mono = mononym_token(y_given, y_fam)
      b_mono = mononym_token(b_given, b_fam)
      if y_mono && b_mono
        mismatches << "##{i}: YAML #{format_name(y_given, y_fam)} vs BibTeX #{format_name(b_given, b_fam)}" unless y_mono == b_mono
        next
      end

      if y_fam != b_fam || y_given != b_given
        mismatches << "##{i}: YAML #{format_name(y_given, y_fam)} vs BibTeX #{format_name(b_given, b_fam)}"
      end
    end

    if mismatches.empty?
      ok '  author matches bibtex_author (BibTeX-parsed)'
    else
      error '  author / bibtex_author mismatch after BibTeX parse:'
      mismatches.each { |m| error "    #{m}" }
    end
  end

  def parse_bibtex_authors(bib_string)
    return nil unless defined?(BibTeX)
    wrapped = "@misc{__pmlint_authors__, author = {#{bib_string}}}"
    bib = BibTeX.parse(wrapped)
    entry = bib['__pmlint_authors__']
    return nil if entry.nil? || entry.author.nil?

    entry.author.map do |name|
      {
        'family' => name.family.to_s,
        'given' => name.given.to_s,
        'prefix' => name.prefix.to_s,
        'suffix' => name.suffix.to_s
      }
    end
  rescue StandardError
    nil
  end

  def name_part(h, key)
    normalize_token(h[key].to_s)
  end

  # Non-empty token when exactly one of given/family is set (BibTeX Name,, or inverted).
  def mononym_token(given_norm, family_norm)
    return given_norm if !given_norm.empty? && family_norm.empty?
    return family_norm if !family_norm.empty? && given_norm.empty?

    nil
  end

  def format_name(given_norm, family_norm)
    # norms are already alnum-folded; show for messages from raw would be nicer,
    # but folded tokens are enough to see Lee vs Z.
    "given=#{given_norm.inspect} family=#{family_norm.inspect}"
  end

  def utf8_string(str)
    s = str.to_s
    s = s.dup if s.frozen?
    s = s.force_encoding('UTF-8')
    unless s.valid_encoding?
      s = s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
    end
    s
  end

  def each_bad_control(str)
    utf8_string(str).each_char do |char|
      cp = char.ord
      next if cp == 0x09 || cp == 0x0A || cp == 0x0D
      # Only true Unicode C0/C1 controls — not UTF-8 continuation bytes misread
      # as characters (e.g. ß = U+00DF must not be flagged via byte 0x9F).
      yield cp if cp <= 0x1F || (0x7F..0x9F).cover?(cp)
    end
  end

  def check_raw_controls(raw, rel)
    each_bad_control(raw) do |cp|
      error "  non-printable character #{format('U+%04X', cp)} in file bytes"
      break
    end
  end

  def check_strings_for_controls(node, rel, path)
    case node
    when String
      each_bad_control(node) do |cp|
        loc = path.empty? ? 'value' : path.join('.')
        error "  non-printable #{format('U+%04X', cp)} in #{loc}"
        break
      end
    when Array
      node.each_with_index { |v, i| check_strings_for_controls(v, rel, path + [i.to_s]) }
    when Hash
      node.each { |k, v| check_strings_for_controls(v, rel, path + [k.to_s]) }
    end
  end

  # Same PDF/conversion artifact classes as intake check_volume on .bib
  # abstract/title — applied to the post fields editors actually edit.
  TEXT_ARTIFACT_FIELDS = %w[abstract title tex_title bibtex_author].freeze

  def check_text_field_artifacts(data, rel)
    found = false
    TEXT_ARTIFACT_FIELDS.each do |field|
      value = data[field]
      next unless value.is_a?(String) && !value.strip.empty?

      TextFieldArtifacts.issues_in(value, field: field).each do |msg|
        error "  #{msg}"
        found = true
      end
    end
    ok '  no PDF/conversion artifacts in abstract/title/author text' unless found
  end

  # Greek / symbol folds used for title comparison (display Unicode ↔ LaTeX names)
  GREEK_TO_NAME = {
    'α' => 'alpha', 'β' => 'beta', 'γ' => 'gamma', 'δ' => 'delta',
    'ε' => 'epsilon', 'ϵ' => 'epsilon', 'ζ' => 'zeta', 'η' => 'eta',
    'θ' => 'theta', 'ι' => 'iota', 'κ' => 'kappa', 'λ' => 'lambda',
    'μ' => 'mu', 'ν' => 'nu', 'ξ' => 'xi', 'π' => 'pi', 'ρ' => 'rho',
    'σ' => 'sigma', 'ς' => 'sigma', 'τ' => 'tau', 'υ' => 'upsilon',
    'φ' => 'phi', 'ϕ' => 'phi', 'χ' => 'chi', 'ψ' => 'psi', 'ω' => 'omega',
    'Α' => 'alpha', 'Β' => 'beta', 'Γ' => 'gamma', 'Δ' => 'delta',
    'Θ' => 'theta', 'Λ' => 'lambda', 'Π' => 'pi', 'Σ' => 'sigma',
    'Φ' => 'phi', 'Ψ' => 'psi', 'Ω' => 'omega'
  }.freeze

  def normalize_token(s)
    t = expand_latex_text(s.to_s)
    # Detex leftovers stuck in author family fields: \textÇakır, textbfSmith
    t = t.gsub(/\A\\?text(bf|it|rm|sc|tt)?/i, '')
    t = fold_latin(t)
    t.downcase.gsub(/[^a-z0-9]/, '')
  end

  def normalize_name_blob(s)
    normalize_token(s)
  end

  def fold_latin(s)
    t = s.to_s.unicode_normalize(:nfkd).gsub(/\p{Mn}/, '')
    t = t.gsub('ß', 'ss').gsub('ẞ', 'ss').gsub('ı', 'i').gsub('İ', 'i')
    # Letters that do not decompose under NFKD to ASCII base letters
    {
      'ø' => 'o', 'Ø' => 'o', 'ł' => 'l', 'Ł' => 'l',
      'æ' => 'ae', 'Æ' => 'ae', 'œ' => 'oe', 'Œ' => 'oe',
      'đ' => 'd', 'Đ' => 'd', 'ħ' => 'h', 'Ħ' => 'h',
      'ð' => 'd', 'Ð' => 'd', 'þ' => 'th', 'Þ' => 'th'
    }.each { |a, b| t = t.gsub(a, b) }
    t
  end

  def expand_latex_text(s)
    t = s.to_s.dup
    # Nordic / Polish BibTeX char macros (before generic unwrap strips the command)
    t.gsub!(/\{\\ss\}|\\ss\{\}|\\ss\b/, 'ss')
    t.gsub!(/\{\\o\}|\\o\{\}|\\o(?![a-zA-Z])/, 'ø')
    t.gsub!(/\{\\O\}|\\O\{\}|\\O(?![a-zA-Z])/, 'Ø')
    t.gsub!(/\{\\l\}|\\l\{\}|\\l(?![a-zA-Z])/, 'ł')
    t.gsub!(/\{\\L\}|\\L\{\}|\\L(?![a-zA-Z])/, 'Ł')
    t.gsub!(/\{\\aa\}|\\aa\{\}|\\aa\b/, 'å')
    t.gsub!(/\{\\AA\}|\\AA\{\}|\\AA\b/, 'Å')
    t.gsub!(/\{\\ae\}|\\ae\{\}|\\ae\b/, 'æ')
    t.gsub!(/\{\\AE\}|\\AE\{\}|\\AE\b/, 'Æ')
    t.gsub!(/\{\\i\}|\\i\{\}|\\i\b/, 'i')
    t.gsub!(/\\'\{\\i\}|\\'\{\i\}/, 'i')
    # Dot accent \.Z / {\.Z}
    t.gsub!(/\{\\\.([A-Za-z])\}|\\\.([A-Za-z])/) { Regexp.last_match[1] || Regexp.last_match[2] }
    t.gsub!(/\\textquotesingle\b/, "'")
    # Named greek / symbols (map to ASCII names for title compare)
    {
      'alpha' => 'alpha', 'beta' => 'beta', 'gamma' => 'gamma', 'delta' => 'delta',
      'epsilon' => 'epsilon', 'lambda' => 'lambda', 'mu' => 'mu', 'sigma' => 'sigma',
      'theta' => 'theta', 'pi' => 'pi', 'phi' => 'phi', 'omega' => 'omega',
      'ell' => 'ell'
    }.each do |cmd, name|
      t.gsub!(/\\text#{cmd}\b/, name)
      t.gsub!(/\\#{cmd}\b/, name)
    end
    # \sqrt{T} and malformed detex \sqrtT (missing braces)
    t.gsub!(/\\sqrt\{([^{}]*)\}/, '\1')
    t.gsub!(/\\sqrt([A-Za-z])/, '\1')
    # Nested / spaced accent forms: {\'{n}}, {\v c}, {\v{c}}, \v{}c, \'{ c}
    t.gsub!(/\{\\'\{([A-Za-z])\}\}/, '\1')
    t.gsub!(/\{\\"\{([A-Za-z])\}\}/, '\1')
    t.gsub!(/\\v\{\}/, '')
    t.gsub!(/\{\\v\s*([A-Za-z])\}|\\v\s*\{([A-Za-z])\}|\\v\s*([A-Za-z])/) do
      Regexp.last_match[1] || Regexp.last_match[2] || Regexp.last_match[3]
    end
    t.gsub!(/\{\\c\s*([A-Za-z])\}|\\c\s*\{([A-Za-z])\}|\\c\s*([A-Za-z])/) do
      Regexp.last_match[1] || Regexp.last_match[2] || Regexp.last_match[3]
    end
    # Occasional Turkish typo \s{c} for ş-like; fold to s/c letter
    t.gsub!(/\\s\{([A-Za-z])\}/, '\1')
    # Broken forms like Clémen\con (missing braces on \c)
    t.gsub!(/\\c(?=[a-zA-Z])/, '')
    # Accent + braced letter: \"{o}, \'{e}, \`{a}, \^{o}, \~{n}
    t.gsub!(/\\["'`^~]\s*\{([A-Za-z])\}/, '\1')
    t.gsub!(/\{\\"\s*([A-Za-z])\}|\\"\s*([A-Za-z])/) { Regexp.last_match[1] || Regexp.last_match[2] }
    t.gsub!(/\\"([A-Za-z])/) { Regexp.last_match[1] } # nystr\"om leftovers
    t.gsub!(/\{\\'\s*([A-Za-z])\}|\\'\s*([A-Za-z])/) { Regexp.last_match[1] || Regexp.last_match[2] }
    t.gsub!(/\{\\`\s*([A-Za-z])\}|\\`\s*([A-Za-z])/) { Regexp.last_match[1] || Regexp.last_match[2] }
    t.gsub!(/\{\\\^\s*([A-Za-z])\}|\\\^\s*([A-Za-z])/) { Regexp.last_match[1] || Regexp.last_match[2] }
    t.gsub!(/\{\\~\s*([A-Za-z])\}|\\~\s*([A-Za-z])/) { Regexp.last_match[1] || Regexp.last_match[2] }
    t.gsub!(/\{\\u\s*\{([A-Za-z])\}\}|\\u\s*\{([A-Za-z])\}/) { Regexp.last_match[1] || Regexp.last_match[2] }
    3.times { t.gsub!(/\\[a-zA-Z]+\*?\s*\{([^{}]*)\}/, '\1') }
    t.gsub!(/[{}]/, '')
    t
  end

  def normalize_title(s)
    t = expand_latex_text(s.to_s)
    # Typographic quotes / dashes ↔ ASCII / TeX equivalents
    t = t.gsub(/[“”«»]/, '"').gsub(/[‘’‛]/, "'")
    t = t.gsub('``', '"').gsub("''", '"').gsub('`', "'")
    t = t.gsub(/---|--|–|—|−/, '-')
    # TeX accent remnants after YAML unescaping: H"older, nos'e, Poincare`e
    t = t.gsub(/([A-Za-z])["'`^~]([A-Za-z])/, '\1\2')
    GREEK_TO_NAME.each { |g, name| t = t.gsub(g, name) }

    # Leftover detex macro *names* glued into title text (no leading backslash)
    # e.g. ensuremathalpha, mathcalvistadpo, textttspin, widetildeo(...), mathttvits
    # \tilde{O} / \widetilde{O} often become tildeo / widetildeo in title text
    t = t.gsub(/widetildeo/i, 'o').gsub(/tildeo/i, 'o')
    %w[ensuremath mathcal mathbb mathrm mathtt mathit mathbf boldsymbol
       texttt textsc textbf textrm textsf textit underline
       widetilde widehat].each do |cmd|
      t = t.gsub(/#{cmd}/i, '')
    end
    t = t.gsub(/\btext(?=[A-Z0-9\[\^])/, '') # \text{DT} / \text{DT}^2 remnants
    t = t.gsub(/\b(left|right)\b/i, '')
    t = t.gsub(/\bbf(?=[\p{L}_])/, '') # bfφ_flow remnants
    # Detex leftover: sqrtt / sqrtT from \sqrt{T}
    t = t.gsub(/\bsqrt/i, '')
    t = fold_latin(t)
    t = t.gsub('√', '')
    t.gsub!(/\bsqrt\s*\{([^{}]*)\}/i, '\1')
    t.gsub!(/[\\$]/, '')
    # Punctuation / grouping that often differs between title and tex_title
    t = t.gsub(/[()]/, '')
    t = t.gsub(/\s+([?!:;,.])/, '\1')
    t.gsub!(/\s+/, ' ')
    t.strip.downcase
  end

  # Placeholders mean "no software link" — acceptable (not a hard error).
  def software_placeholder?(value)
    s = value.to_s.strip
    return true if s.empty?
    return true if s.match?(/\A(nan|n\/?a|n\.?a\.?|none|null|\.|-+)\z/i)
    return true if s.match?(/\A(no\s*code.*|nocodeprovided.*|not\s*available|unavailable)\z/i)
    # Stray OpenReview/base64 fragments accidentally pasted into software
    return true if s.match?(/\A[A-Za-z0-9]{5}\z/)
    false
  end

  def software_ok?(value)
    return true if software_placeholder?(value)
    urlish?(value)
  end

  def urlish?(value)
    s = value.to_s.strip
    return false if s.empty?
    return false if software_placeholder?(s)
    return false if s.start_with?('/') && !s.start_with?('//') # local paths
    # Legacy PMLR paper keys with spaces in the path (e.g. de bock17a)
    if s.match?(/\Ahttps?:\/\/proceedings\.mlr\.press\//i)
      return true
    end
    # Labeled / multi-link blurbs: "(Name) https://... (Other) https://..."
    urls = s.scan(%r{https?://[^\s\)\]\"']+}i).map { |u| u.sub(/[.,;]+$/, '') }
    if urls.length >= 1
      return urls.all? { |u| urlish_one?(u) }
    end
    # Collapse whitespace typos: "https: //github.com/...", "github. com/..."
    compact = s.gsub(/\s+/, '')
    compact = compact.sub(/\ACode:/i, '')
    compact = "https://#{compact}" if compact.match?(/\A(www\.)?github\.com\//i)
    compact = "https://#{compact}" if compact.match?(/\A(www\.)?gitlab\.com\//i)
    compact = "https://#{compact}" if compact.match?(/\A[\w.-]+\.github\.io(\/|\z)/i)
    compact = "https://#{compact}" if compact.match?(/\A[\w.-]+\.(io|org|com|ai|dev|ms)(\/|\z)/i) && !compact.match?(/\Ahttps?:/i)
    # GitHub org/repo shorthand (doronHav/WassersteinFlowMatching)
    if compact.match?(/\A[\w.-]+\/[\w.\/-]+\z/) && !compact.include?('.')
      compact = "https://github.com/#{compact}"
    end
    # Multi-URL fields: accept if every http(s) token looks like a URL
    if compact.include?(',') || compact.scan(/https?:/i).length > 1
      parts = compact.split(/,|AND/i).map(&:strip).reject(&:empty?)
      return parts.all? { |p| urlish_one?(p) } if parts.length > 1
    end
    # First token only when trailing junk words ("aka.ms/foo Topics")
    if s.match?(/\s/) && !s.match?(/https?:/i)
      first = s.split(/\s+/).first
      return urlish?(first) if first && first != s
    end
    urlish_one?(compact)
  end

  def urlish_one?(s)
    s = s.to_s.strip
    return false if s.empty?
    # Strip editorial labels, but never the URL scheme (https?:)
    s = s.sub(/\ACode:\s*/i, '')
    s = s.sub(/\A(?:URL|Link|Software|Homepage):\s*/i, '')
    return true if s.match?(/\Ahttps?:\/\/[^\/\s?#]+(?:[\/?#].*)?\z/i)
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
    label = msg.strip
    label = "#{@current_rel}: #{label}" if @current_rel && !label.start_with?(@current_rel)
    @errors << label
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
      puts
      puts Colour.bold('  Issues:')
      @errors.each { |e| puts Colour.red("    - #{e}") }
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
