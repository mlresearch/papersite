# frozen_string_literal: true

require 'set'
require 'yaml'
require 'zlib'
require_relative 'tex_hyphenator'

# PDF text extractors often keep a soft line-break hyphen as ASCII "-" and turn
# the newline into a space, yielding mid-word artifacts like "knowl- edge" or
# compound breaks like "state- of-the-art".
#
# Genuine en/em dashes do not look like this:
#   - en/em with spaces: "word – word" / "word — word" (space before the dash)
#   - numeric ranges: "1990–2000" / "1990--2000" (no space after)
# So the pattern "letter- lowercase" (no space before, one space after) is a
# reliable PDF wrap signal. Unicode en/em dashes are handled separately by
# tidy_bib_unicode (→ "--" / "---").
#
# Curated lists live in lib/pdf_wrap_hyphens.yml (edit there, not here).
# Optional TeX Liang patterns (lib/hyphenation/) give a high-confidence *join*
# signal and can override function_left false drops (e.g. in- variant →
# invariant). Missing patterns fail open to YAML + default join.
#
# Decision order:
#   1. right contains "-"     → keep hyphen (compound continuation)
#   2. compound_right match   → keep hyphen
#   3. TeX break confirms     → join if word (or long fragments)
#   4. function_left match    → drop hyphen, keep space
#   5. default                → join if word (or long fragments)
# A proposed join whose compressed form is not an English word keeps the
# hyphen when either side is short (abbreviations: abc- mart). Long+long
# OOV still joins (line-wrapped names).
module PdfWrapHyphens
  CONFIG_PATH = File.expand_path('pdf_wrap_hyphens.yml', __dir__)
  LIB_DIR = __dir__

  # letter(s), ASCII hyphen, single space, lowercase continuation
  PATTERN = /([A-Za-z]+)- ([a-z][A-Za-z-]*)/
  # Same artifact when a YAML/BibTeX line break sits between hyphen and continuation
  # (e.g. "ap-\n  proximations" → loaded YAML "ap- proximations").
  MULTILINE_PATTERN = /([A-Za-z]+)-\n[ \t]*([a-z][A-Za-z-]*)/

  module_function

  def function_left
    lists[:function_left]
  end

  def compound_right
    lists[:compound_right]
  end

  def tex_hyphenator
    lists[:tex_hyphenator]
  end

  def words
    lists[:words]
  end

  # Reload YAML / patterns (tests). Returns self.
  def reload!
    @lists = nil
    lists
    self
  end

  # Temporarily use an alternate YAML config (tests). Restores on ensure.
  def with_config_path(path)
    previous = @config_path_override
    @config_path_override = path
    @lists = nil
    yield
  ensure
    @config_path_override = previous
    @lists = nil
  end

  def config_path
    @config_path_override || CONFIG_PATH
  end
  module_function :config_path

  # :join, :keep_hyphen, or :drop_hyphen (remove "-" but keep the space)
  def decision(left, right)
    decision_detail(left, right)[:action]
  end

  # True when +right+ continues a hyphenated compound (e.g. "of-the-art").
  def compound_continuation?(right)
    right.match?(/[A-Za-z]-[A-Za-z]/)
  end
  module_function :compound_continuation?

  # Split "ity---" → ["ity", "---"]; "of-" → ["of", "-"]; else [right, ""].
  def split_trailing_dashes(right)
    if right =~ /\A([A-Za-z]+)(-+)\z/
      [$1, $2]
    else
      [right, '']
    end
  end
  module_function :split_trailing_dashes

  # Richer result for check messages: { action:, reason: }
  def decision_detail(left, right)
    if compound_continuation?(right)
      return { action: :keep_hyphen, reason: 'compound continuation' }
    end

    letters, dashes = split_trailing_dashes(right)

    # Mid-compound break leaving a single trailing hyphen ("state- of- …").
    if dashes == '-'
      return { action: :keep_hyphen, reason: 'compound continuation' }
    end

    # Syllable before an em-dash run ("heterogene- ity---") → join letters.
    # Longer dash runs are not compound hyphens.
    right_token = letters[/\A[A-Za-z]+/]
    unless right_token
      return { action: :join, reason: 'default' }
    end

    if compound_right.include?(right_token.downcase)
      return { action: :keep_hyphen, reason: 'compound_right' }
    end

    hyphenator = tex_hyphenator
    if hyphenator && hyphenator.break_between?(left, right_token)
      if dictionary_word?("#{left}#{right_token}")
        return { action: :join, reason: 'tex_hyphenation' }
      end
      # TeX liked the break but the compression is not a word: do not skip
      # function_left (of- magnitude) or the abbreviation keep (abc- mart).
    end

    if function_left.include?(left.downcase)
      return { action: :drop_hyphen, reason: 'function_left' }
    end

    reason = if hyphenator && hyphenator.break_between?(left, right_token)
               'tex_hyphenation'
             elsif hyphenator
               'default (no tex break)'
             else
               'default (tex unavailable)'
             end
    join_if_word(left, right_token, reason)
  end

  # Keep hyphen for short non-words (abc-mart). Long wraps of names still join.
  SHORT_JOIN_MAX = 3

  def join_if_word(left, right_token, reason)
    joined = "#{left}#{right_token}"
    if dictionary_word?(joined)
      return { action: :join, reason: reason }
    end
    # Short left + not a word: abc- mart, k- means. Long left: names / wraps.
    if left.length > SHORT_JOIN_MAX
      return { action: :join, reason: "#{reason}, oov long" }
    end
    { action: :keep_hyphen, reason: 'not a dictionary word' }
  end
  module_function :join_if_word

  def dictionary_word?(token)
    w = token.to_s.downcase.gsub(/[^a-z]/, '')
    return false if w.empty?
    set = words
    return false if set.nil? || set.empty?
    return true if set.include?(w)

    inflection_stems(w).any? { |s| set.include?(s) }
  end
  module_function :dictionary_word?

  def inflection_stems(w)
    stems = []
    if w.end_with?('ies') && w.length > 5
      stems << "#{w[0..-4]}y"
    end
    if w.end_with?('es') && w.length > 4
      stems << w[0..-3]
    end
    if w.end_with?('s') && w.length > 3 && !w.end_with?('ss', 'us', 'is')
      stems << w[0..-2]
    end
    if w.end_with?('ing') && w.length >= 5
      stem = w[0..-4]
      stems << stem
      stems << "#{stem}e"
      stems << stem[0..-2] if stem.length > 3 && stem[-1] == stem[-2]
    end
    if w.end_with?('ed') && w.length > 4
      stem = w[0..-3]
      stems << stem
      stems << "#{stem}e"
      stems << stem[0..-2] if stem.length > 3 && stem[-1] == stem[-2]
    end
    if w.end_with?('ly') && w.length > 5
      stems << w[0..-3]
    end
    if w.end_with?('ity') && w.length > 6
      stems << w[0..-4]           # optimality → optimal
      stems << "#{w[0..-4]}e"     # sparsity → sparse (approx)
    end
    if w.end_with?('our') && w.length > 5
      stems << "#{w[0..-4]}or"    # behaviour → behavior
    end
    if w.end_with?('ours') && w.length > 6
      stems << "#{w[0..-5]}or"
    end
    if w.end_with?('isation') && w.length > 8
      stems << "#{w[0..-8]}ization"
      stems << w[0..-8]
    end
    if w.end_with?('ising') && w.length > 6
      stems << "#{w[0..-6]}ize"
      stems << "#{w[0..-6]}ise"
    end
    if w.end_with?('ises') && w.length > 5
      stems << "#{w[0..-4]}ize"
      stems << "#{w[0..-4]}ise"
    end
    if w.end_with?('ability') && w.length > 8
      stems << "#{w[0..-8]}able"  # sustainability → sustainable
    end
    stems
  end
  module_function :inflection_stems

  def keep_hyphen?(left, right)
    decision(left, right) == :keep_hyphen
  end

  # Replace each wrap hyphen. Returns [new_content, fix_count].
  def fix(content)
    count = 0
    # Repeat: "state- of- the- art" needs several passes.
    loop do
      changed = false
      content = content.gsub(PATTERN) do
        left = Regexp.last_match(1)
        right = Regexp.last_match(2)
        changed = true
        count += 1
        replacement_for(left, right)
      end
      content = content.gsub(MULTILINE_PATTERN) do
        left = Regexp.last_match(1)
        right = Regexp.last_match(2)
        changed = true
        count += 1
        replacement_for(left, right)
      end
      break unless changed
    end
    [content, count]
  end

  def replacement_for(left, right)
    letters, dashes = split_trailing_dashes(right)
    case decision(left, right)
    when :keep_hyphen then "#{left}-#{right}"
    when :drop_hyphen then "#{left} #{right}"
    else "#{left}#{letters}#{dashes}"
    end
  end
  module_function :replacement_for

  # Yield [left, right, line_number, line_preview] for each match.
  # Includes cross-line wraps (counted on the line that holds the hyphen).
  def each_occurrence(content)
    # Same-line first
    content.each_line.with_index(1) do |line, lineno|
      line.scan(PATTERN) do |left, right|
        preview = line.strip
        preview = "#{preview[0, 80]}..." if preview.length > 80
        yield left, right, lineno, preview
      end
    end
    # Cross-line (YAML folded abstracts): report on the hyphen line
    offset = 0
    content.scan(MULTILINE_PATTERN) do
      left = Regexp.last_match(1)
      right = Regexp.last_match(2)
      match_start = Regexp.last_match.begin(0)
      lineno = content[0...match_start].count("\n") + 1
      line = content[0...match_start].lines.last.to_s + right
      preview = line.strip
      preview = "#{preview[0, 80]}..." if preview.length > 80
      yield left, right, lineno, preview
      offset = match_start + 1
    end
  end

  def lists
    @lists ||= load_lists
  end
  module_function :lists

  def load_lists
    path = config_path
    unless File.file?(path)
      raise "Missing #{path} — curated wrap-hyphen lists are required"
    end

    data = YAML.safe_load(File.read(path), aliases: true)
    unless data.is_a?(Hash)
      raise "Invalid #{path}: expected a mapping with function_left / compound_right"
    end

    {
      function_left: normalize_token_list(data['function_left'], 'function_left', path),
      compound_right: normalize_token_list(data['compound_right'], 'compound_right', path),
      tex_hyphenator: load_tex_hyphenator(data['tex_hyphenation']),
      words: load_word_set(data['dictionary'])
    }
  rescue Psych::SyntaxError, Psych::DisallowedClass => e
    raise "YAML error loading #{path}: #{e.message}"
  end
  module_function :load_lists

  def normalize_token_list(raw, name, path = config_path)
    unless raw.is_a?(Array) && !raw.empty?
      raise "Invalid #{path}: #{name} must be a non-empty list"
    end

    raw.map { |t| t.to_s.strip.downcase }.reject(&:empty?).to_set
  end
  module_function :normalize_token_list

  def load_tex_hyphenator(section)
    return nil if ENV['PMLR_DISABLE_TEX_HYPHEN'] == '1'
    return nil unless section.is_a?(Hash)
    return nil if section['enabled'] == false

    patterns = resolve_lib_path(section['patterns'])
    exceptions = resolve_lib_path(section['exceptions'])
    unless patterns && File.file?(patterns)
      warn "PdfWrapHyphens: TeX patterns not found (#{section['patterns']}); " \
           "failing open without tex_hyphenation join signal"
      return nil
    end

    TexHyphenator.new(
      patterns,
      exceptions_path: (exceptions if exceptions && File.file?(exceptions)),
      left_min: (section['left_min'] || 2).to_i,
      right_min: (section['right_min'] || 3).to_i
    )
  end
  module_function :load_tex_hyphenator

  def load_word_set(section)
    return Set.new if ENV['PMLR_DISABLE_WORD_DICT'] == '1'
    return Set.new unless section.is_a?(Hash)
    return Set.new if section['enabled'] == false

    words = Set.new
    extras = section['extras']
    if extras.is_a?(Array)
      extras.each { |t| words.add(t.to_s.strip.downcase) unless t.to_s.strip.empty? }
    end

    path = resolve_lib_path(section['words'])
    if path && File.file?(path)
      io = path.end_with?('.gz') ? Zlib::GzipReader.open(path) : File.open(path)
      begin
        io.each_line do |line|
          w = line.strip.downcase
          next if w.empty? || !w.match?(/\A[a-z]+\z/)
          words.add(w)
        end
      ensure
        io.close
      end
    elsif path
      warn "PdfWrapHyphens: word list not found (#{section['words']}); " \
           "join-confidence check disabled"
    end

    words
  end
  module_function :load_word_set

  def resolve_lib_path(rel)
    return nil if rel.nil? || rel.to_s.empty?
    rel = rel.to_s
    return rel if rel.start_with?('/')

    File.expand_path(rel, LIB_DIR)
  end
  module_function :resolve_lib_path
end
